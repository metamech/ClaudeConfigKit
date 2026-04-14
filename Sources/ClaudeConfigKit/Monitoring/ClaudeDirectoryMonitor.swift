import Foundation
import CoreServices
import Logging

// MARK: - ClaudeDirectoryMonitor

/// FSEvents-based watcher for the `~/.claude` directory that parses Claude
/// Code's configuration, stats-cache, session histories, and plan files,
/// then publishes the results to a ``ClaudeDirectoryState`` on the main actor.
///
/// FSEvents delivers events on a private `DispatchQueue`, not on the actor's
/// executor.  The C callback calls a `nonisolated` bridge method that schedules
/// a `Task` — the task then hops onto the actor to do real work.
///
/// A configurable debounce coalesces rapid bursts of change events into a single
/// parse pass. Multi-path monitoring is supported.
///
/// ## Pause / Resume
///
/// ``pause()`` tears down the FSEvents source and cancels any pending debounce
/// work without finishing `fileEvents` — the AsyncStream and its consumer tasks
/// remain alive across the suspension window.  ``resume()`` reinstalls the
/// FSEvents source so events flow again.  Use these instead of
/// ``stopMonitoring()`` / ``startMonitoring()`` whenever you want to
/// temporarily silence the monitor (e.g. while the host application is in the
/// background) without invalidating existing stream consumers.
public actor ClaudeDirectoryMonitor: CodingAgentDirectoryMonitor {

    // MARK: - Private state

    private let directoryState: ClaudeDirectoryState
    private var monitoredPaths: [URL]
    private let debounceInterval: Duration

    public private(set) var isMonitoring: Bool = false

    /// `true` while the monitor has been paused via ``pause()`` but not yet
    /// resumed.  The actor is still considered "monitoring" (`isMonitoring`
    /// remains `true`) — only the FSEvents source is temporarily suspended.
    public private(set) var isPaused: Bool = false

    private var eventStream: FSEventStreamRef?
    private let callbackQueue: DispatchQueue
    private var debounceTask: Task<Void, Never>?
    private var parseErrors: [ClaudeDirectoryError] = []

    private var fileEventContinuation: AsyncStream<[FileChangeEvent]>.Continuation?
    private let _fileEvents: AsyncStream<[FileChangeEvent]>

    /// Paths accumulated from FSEvents callbacks during the current debounce window.
    /// Cleared after each parse pass.
    private var pendingChangedPaths: Set<String> = []

    /// Last-seen modification date per plan file URL, keyed across all scanned plan directories.
    private var lastPlanModDates: [URL: Date] = [:]
    /// Cached parse result per plan file URL; reused when modification date is unchanged.
    private var cachedPlans: [URL: ClaudePlan] = [:]

    private static let logger = Logger(label: "com.metamech.ClaudeConfigKit.ClaudeDirectoryMonitor")

    // MARK: - Init

    /// Creates a monitor watching the given paths with the specified debounce interval.
    ///
    /// - Parameters:
    ///   - directoryState: The state object to publish parsed results to.
    ///   - monitoredPaths: Directories to monitor. Defaults to `[~/.claude]`.
    ///   - debounceInterval: How long to wait before coalescing events. Defaults to 1500ms.
    public init(
        directoryState: ClaudeDirectoryState,
        monitoredPaths: [URL]? = nil,
        debounceInterval: Duration = .milliseconds(1500)
    ) {
        self.directoryState = directoryState
        self.monitoredPaths = monitoredPaths
            ?? [URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude")]
        self.debounceInterval = debounceInterval
        self.callbackQueue = DispatchQueue(
            label: "com.metamech.ClaudeConfigKit.ClaudeDirectoryMonitor",
            qos: .utility
        )

        var continuation: AsyncStream<[FileChangeEvent]>.Continuation!
        self._fileEvents = AsyncStream { continuation = $0 }
        self.fileEventContinuation = continuation
    }

    /// Convenience init for single-directory monitoring.
    public init(
        directoryState: ClaudeDirectoryState,
        claudeDirectory: URL?,
        debounceInterval: Duration = .milliseconds(1500)
    ) {
        let dir = claudeDirectory
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude")
        self.init(
            directoryState: directoryState,
            monitoredPaths: [dir],
            debounceInterval: debounceInterval
        )
    }

    // MARK: - Public API

    /// An `AsyncStream` of raw file change events, yielded before debounce.
    public nonisolated var fileEvents: AsyncStream<[FileChangeEvent]> {
        _fileEvents
    }

    /// Update the monitored paths at runtime. Tears down and reinstalls the FSEvents stream.
    public func updatePaths(_ paths: [URL]) async {
        let wasMonitoring = isMonitoring
        if wasMonitoring {
            await stopMonitoring()
        }
        monitoredPaths = paths
        if wasMonitoring {
            await startMonitoring()
        }
    }

    // MARK: - CodingAgentDirectoryMonitor

    public func startMonitoring() async {
        guard !isMonitoring else { return }

        // Defensive guard: a previous stopMonitoring() call finished the
        // continuation.  The fileEvents AsyncStream cannot be revived; callers
        // that cycled through stop→start must create a new monitor instance.
        // Prefer pause()/resume() to avoid this.
        guard fileEventContinuation != nil else {
            Self.logger.warning("startMonitoring() called after stopMonitoring() exhausted the fileEvents continuation — use pause()/resume() to temporarily suspend, or create a new instance to restart from scratch")
            return
        }

        let validPaths = monitoredPaths.filter { url in
            FileManager.default.fileExists(atPath: url.path)
        }

        guard !validPaths.isEmpty else {
            Self.logger.warning("No monitored paths exist — monitoring skipped")
            return
        }

        installFSEventStream(paths: validPaths)
        isMonitoring = (eventStream != nil)

        if isMonitoring {
            Self.logger.info("Started monitoring \(validPaths.map(\.path))")
            await runParsePass()
        }
    }

    public func stopMonitoring() async {
        guard isMonitoring else { return }

        debounceTask?.cancel()
        debounceTask = nil

        teardownFSEventStream()
        isMonitoring = false
        isPaused = false
        fileEventContinuation?.finish()
        fileEventContinuation = nil

        Self.logger.info("Stopped monitoring")
    }

    /// Temporarily suspends FSEvents delivery without finishing the `fileEvents`
    /// stream.  Cancels any pending debounce work.
    ///
    /// - No-op if not currently monitoring (`isMonitoring == false`).
    /// - No-op if already paused (`isPaused == true`).
    public func pause() async {
        guard isMonitoring, !isPaused else { return }

        debounceTask?.cancel()
        debounceTask = nil

        teardownFSEventStream()
        isPaused = true

        Self.logger.debug("Directory monitor paused")
    }

    /// Reinstalls the FSEvents source after a ``pause()``.
    ///
    /// Does **not** run an initial parse pass — the monitor resumes exactly
    /// where it left off and will react to the next file-system event.
    ///
    /// - No-op if not currently monitoring (`isMonitoring == false`).
    /// - No-op if not paused (`isPaused == false`).
    public func resume() async {
        guard isMonitoring, isPaused else { return }

        let validPaths = monitoredPaths.filter { url in
            FileManager.default.fileExists(atPath: url.path)
        }

        guard !validPaths.isEmpty else {
            Self.logger.warning("No monitored paths exist on resume — staying paused")
            return
        }

        installFSEventStream(paths: validPaths)
        if eventStream != nil {
            isPaused = false
            Self.logger.debug("Directory monitor resumed")
        } else {
            Self.logger.error("FSEventStream reinstall failed on resume — staying paused")
        }
    }

    // MARK: - FSEvents stream

    private func installFSEventStream(paths: [URL]) {
        let pathsToWatch = paths.map(\.path) as CFArray

        let selfPtr = Unmanaged.passRetained(self as AnyObject).toOpaque()

        var context = FSEventStreamContext(
            version: 0,
            info: selfPtr,
            retain: nil,
            release: { ptr in
                guard let ptr else { return }
                Unmanaged<AnyObject>.fromOpaque(ptr).release()
            },
            copyDescription: nil
        )

        let latency: CFTimeInterval = 0.5

        let flags: FSEventStreamCreateFlags =
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes) |
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents) |
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagNoDefer)

        let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, info, numEvents, eventPaths, eventFlags, _ in
                guard let info else { return }
                let monitor = Unmanaged<AnyObject>
                    .fromOpaque(info)
                    .takeUnretainedValue() as! ClaudeDirectoryMonitor

                let cfArray = unsafeBitCast(eventPaths, to: NSArray.self)
                guard let cfPaths = cfArray as? [String] else { return }
                let paths = Array(cfPaths.prefix(numEvents))

                let flagsPtr = eventFlags
                var events: [FileChangeEvent] = []
                let now = Date()
                for i in 0..<numEvents {
                    let eventFlag = EventFlags(rawValue: UInt32(flagsPtr[i]))
                    events.append(FileChangeEvent(path: paths[i], flags: eventFlag, timestamp: now))
                }

                monitor.handleFSEventsCallback(paths: paths, events: events)
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            flags
        )

        guard let stream else {
            Self.logger.error("FSEventStreamCreate returned nil")
            Unmanaged<AnyObject>.fromOpaque(selfPtr).release()
            return
        }

        FSEventStreamSetDispatchQueue(stream, callbackQueue)

        guard FSEventStreamStart(stream) else {
            Self.logger.error("FSEventStreamStart failed")
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            return
        }

        eventStream = stream
    }

    private func teardownFSEventStream() {
        guard let stream = eventStream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        eventStream = nil
    }

    // MARK: - FSEvents → actor bridge

    nonisolated func handleFSEventsCallback(paths: [String], events: [FileChangeEvent]) {
        Task {
            await self.scheduleDebounce(paths: paths, events: events)
        }
    }

    private func scheduleDebounce(paths: [String], events: [FileChangeEvent]) {
        // Yield raw events before debounce
        fileEventContinuation?.yield(events)

        // Accumulate paths across rapid-fire callbacks within the debounce window.
        pendingChangedPaths.formUnion(paths)

        debounceTask?.cancel()
        debounceTask = Task { [weak self, debounceInterval] in
            do {
                try await Task.sleep(for: debounceInterval)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            Self.logger.debug("Debounce fired for \(paths.count) changed path(s)")
            await self?.runParsePass()
        }
    }

    // MARK: - Parse pass

    private func runParsePass() async {
        parseErrors.removeAll()

        // Use the first monitored path as the claude directory for parsing
        guard let claudeDirectory = monitoredPaths.first else { return }

        // Snapshot and clear the accumulated paths so the next debounce window
        // starts clean even while this parse pass is in flight.
        let changedPaths = pendingChangedPaths
        pendingChangedPaths.removeAll()

        // Determine which parsers to run based on the changed paths.
        // Fall back to running all parsers when no paths are known (e.g. on
        // startup, or if the set was cleared unexpectedly).
        if changedPaths.isEmpty {
            await parseSettings(in: claudeDirectory)
            await parseStatsCache(in: claudeDirectory)
            await parseSessionHistories(in: claudeDirectory)
            await parsePlans(in: claudeDirectory)
        } else {
            let needsSettings   = changedPaths.contains { $0.hasSuffix("settings.json") }
            let needsStats      = changedPaths.contains { $0.hasSuffix("stats-cache.json") }
            let needsHistories  = changedPaths.contains { $0.contains("history.jsonl") }
            let needsPlans      = changedPaths.contains { path in
                path.contains("/plans/") && path.hasSuffix(".md")
            }
            // If a changed path doesn't match any known pattern, run all parsers
            // as a safety fallback so no update is silently dropped.
            let hasUnknown = changedPaths.contains { path in
                !path.hasSuffix("settings.json") &&
                !path.hasSuffix("stats-cache.json") &&
                !path.contains("history.jsonl") &&
                !(path.contains("/plans/") && path.hasSuffix(".md"))
            }

            if needsSettings  || hasUnknown { await parseSettings(in: claudeDirectory) }
            if needsStats     || hasUnknown { await parseStatsCache(in: claudeDirectory) }
            if needsHistories || hasUnknown { await parseSessionHistories(in: claudeDirectory) }
            if needsPlans     || hasUnknown { await parsePlans(in: claudeDirectory) }
        }

        let errors = parseErrors
        let now = Date()
        let state = directoryState

        Task { @MainActor in
            state.errors = errors
            state.lastUpdated = now
        }
    }

    // MARK: - Individual parsers

    private func parseSettings(in claudeDirectory: URL) async {
        let url = claudeDirectory.appendingPathComponent("settings.json")

        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let state = directoryState
            try await MainActor.run {
                state.settings = try JSONDecoder().decode(ClaudeSettings.self, from: data)
            }
            Self.logger.debug("Parsed settings.json")
        } catch let error as CocoaError where error.code == .fileReadNoPermission {
            parseErrors.append(.accessDenied(url.path))
            Self.logger.warning("Access denied: \(url.path)")
        } catch {
            parseErrors.append(.parseError(url.path, error))
            Self.logger.error("Failed to parse settings.json: \(error)")
        }
    }

    private func parseStatsCache(in claudeDirectory: URL) async {
        let url = claudeDirectory.appendingPathComponent("stats-cache.json")

        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let state = directoryState
            try await MainActor.run {
                state.statsCache = try JSONDecoder().decode(ClaudeStatsCache.self, from: data)
            }
            Self.logger.debug("Parsed stats-cache.json")
        } catch let error as CocoaError where error.code == .fileReadNoPermission {
            parseErrors.append(.accessDenied(url.path))
        } catch {
            parseErrors.append(.parseError(url.path, error))
            Self.logger.error("Failed to parse statsCache.json: \(error)")
        }
    }

    private func parseSessionHistories(in claudeDirectory: URL) async {
        let projectsURL = claudeDirectory.appendingPathComponent("projects")

        guard FileManager.default.fileExists(atPath: projectsURL.path) else {
            return
        }

        var updatedHistories: [String: [ClaudeSessionHistoryEntry]] = [:]

        do {
            let projectDirs = try FileManager.default.contentsOfDirectory(
                at: projectsURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsHiddenFiles
            )

            for projectDir in projectDirs {
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(
                    atPath: projectDir.path, isDirectory: &isDir
                ), isDir.boolValue else { continue }

                let historyURL = projectDir.appendingPathComponent("history.jsonl")
                guard FileManager.default.fileExists(atPath: historyURL.path) else { continue }

                let entries = await parseJSONL(at: historyURL)
                updatedHistories[projectDir.lastPathComponent] = entries
            }
        } catch {
            parseErrors.append(.parseError(projectsURL.path, error))
            Self.logger.error("Failed to enumerate projects directory: \(error)")
        }

        let histories = updatedHistories
        let state = directoryState
        Task { @MainActor in
            state.sessionHistories = histories
        }
    }

    private func parsePlans(in claudeDirectory: URL) async {
        var updatedPlans: [String: [ClaudePlan]] = [:]

        // Scan global plans directory (~/.claude/plans/)
        let globalPlansDir = claudeDirectory.appendingPathComponent("plans")
        let globalPlans = scanPlansDirectory(globalPlansDir)
        if !globalPlans.isEmpty {
            updatedPlans["_global"] = globalPlans
        }

        // Scan per-project plans directories (~/.claude/projects/*/plans/)
        let projectsURL = claudeDirectory.appendingPathComponent("projects")
        if FileManager.default.fileExists(atPath: projectsURL.path) {
            do {
                let projectDirs = try FileManager.default.contentsOfDirectory(
                    at: projectsURL,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: .skipsHiddenFiles
                )

                for projectDir in projectDirs {
                    var isDir: ObjCBool = false
                    guard FileManager.default.fileExists(
                        atPath: projectDir.path, isDirectory: &isDir
                    ), isDir.boolValue else { continue }

                    let plansDir = projectDir.appendingPathComponent("plans")
                    let projectPlans = scanPlansDirectory(plansDir)
                    if !projectPlans.isEmpty {
                        updatedPlans[projectDir.lastPathComponent] = projectPlans
                    }
                }
            } catch {
                parseErrors.append(.parseError(projectsURL.path, error))
                Self.logger.error("Failed to enumerate projects for plans: \(error)")
            }
        }

        let plans = updatedPlans
        let state = directoryState
        Task { @MainActor in
            state.plans = plans
        }
    }

    /// Scans a directory for markdown plan files and returns parsed `ClaudePlan` instances.
    ///
    /// Uses a single batch `contentsOfDirectory` call (with `.contentModificationDateKey`) to
    /// enumerate files and their modification dates, then skips reading files whose modification
    /// date hasn't changed since the last scan.  Fresh reads are cached so unchanged files cost
    /// only a date comparison per debounce pass.
    private func scanPlansDirectory(_ plansDir: URL) -> [ClaudePlan] {
        guard FileManager.default.fileExists(atPath: plansDir.path) else { return [] }

        // Single syscall: enumerate all files plus their modification dates.
        let allFiles: [URL]
        do {
            allFiles = try FileManager.default.contentsOfDirectory(
                at: plansDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            ).filter { $0.pathExtension.lowercased() == "md" }
        } catch {
            parseErrors.append(.parseError(plansDir.path, error))
            return []
        }

        // Track which URLs are still present so we can evict deleted entries.
        var seenURLs: Set<URL> = []
        var plans: [ClaudePlan] = []

        for file in allFiles {
            seenURLs.insert(file)

            // Extract the modification date from the already-fetched resource values —
            // no extra attributesOfItem / lstat call needed.
            let modDate: Date
            if let values = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
               let date = values.contentModificationDate {
                modDate = date
            } else {
                modDate = Date()
            }

            // Cache hit: date unchanged — reuse the previous parse result.
            if let cached = cachedPlans[file], lastPlanModDates[file] == modDate {
                plans.append(cached)
                continue
            }

            // Cache miss or date changed: read and parse the file.
            do {
                let content = try String(contentsOf: file, encoding: .utf8)
                let plan = ClaudePlan(
                    filePath: file.path,
                    content: content,
                    lastModified: modDate
                )
                cachedPlans[file] = plan
                lastPlanModDates[file] = modDate
                plans.append(plan)
            } catch {
                parseErrors.append(.parseError(file.path, error))
                Self.logger.error("Failed to read plan \(file.lastPathComponent): \(error)")
            }
        }

        // Evict entries for files that no longer exist in this directory.
        let dirsURLs = Set(lastPlanModDates.keys.filter { $0.deletingLastPathComponent() == plansDir })
        for staleURL in dirsURLs.subtracting(seenURLs) {
            lastPlanModDates.removeValue(forKey: staleURL)
            cachedPlans.removeValue(forKey: staleURL)
        }

        return plans
    }

    // MARK: - JSONL helper

    private func parseJSONL(at url: URL) async -> [ClaudeSessionHistoryEntry] {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
            parseErrors.append(.parseError(url.path, URLError(.cannotOpenFile)))
            return []
        }

        let lineDataPairs: [(String, Data)] = raw.components(separatedBy: .newlines).compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return nil }
            return (url.lastPathComponent, data)
        }

        return await MainActor.run {
            let decoder = JSONDecoder()
            var entries: [ClaudeSessionHistoryEntry] = []
            for (fileName, data) in lineDataPairs {
                do {
                    let entry = try decoder.decode(ClaudeSessionHistoryEntry.self, from: data)
                    entries.append(entry)
                } catch {
                    Self.logger.debug("Skipping malformed JSONL line in \(fileName): \(error)")
                }
            }
            return entries
        }
    }
}
