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
/// A 500 ms debounce coalesces rapid bursts of change events into a single
/// parse pass.
public actor ClaudeDirectoryMonitor: CodingAgentDirectoryMonitor {

    // MARK: - Private state

    private let directoryState: ClaudeDirectoryState
    private let claudeDirectory: URL

    public private(set) var isMonitoring: Bool = false

    private var eventStream: FSEventStreamRef?
    private let callbackQueue: DispatchQueue
    private var debounceTask: Task<Void, Never>?
    private var parseErrors: [ClaudeDirectoryError] = []

    private static let logger = Logger(label: "com.metamech.ClaudeConfigKit.ClaudeDirectoryMonitor")

    // MARK: - Init

    public init(
        directoryState: ClaudeDirectoryState,
        claudeDirectory: URL? = nil
    ) {
        self.directoryState = directoryState
        self.claudeDirectory = claudeDirectory
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude")
        self.callbackQueue = DispatchQueue(
            label: "com.metamech.ClaudeConfigKit.ClaudeDirectoryMonitor",
            qos: .utility
        )
    }

    // MARK: - CodingAgentDirectoryMonitor

    public func startMonitoring() async {
        guard !isMonitoring else { return }

        guard FileManager.default.fileExists(atPath: claudeDirectory.path) else {
            Self.logger.warning("~/.claude not found at \(self.claudeDirectory.path) — monitoring skipped")
            return
        }

        installFSEventStream()
        isMonitoring = (eventStream != nil)

        if isMonitoring {
            Self.logger.info("Started monitoring \(self.claudeDirectory.path)")
            await runParsePass()
        }
    }

    public func stopMonitoring() async {
        guard isMonitoring else { return }

        debounceTask?.cancel()
        debounceTask = nil

        teardownFSEventStream()
        isMonitoring = false

        Self.logger.info("Stopped monitoring \(self.claudeDirectory.path)")
    }

    // MARK: - FSEvents stream

    private func installFSEventStream() {
        let pathsToWatch = [claudeDirectory.path] as CFArray

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
            { _, info, numEvents, eventPaths, _, _ in
                guard let info else { return }
                let monitor = Unmanaged<AnyObject>
                    .fromOpaque(info)
                    .takeUnretainedValue() as! ClaudeDirectoryMonitor

                let cfArray = unsafeBitCast(eventPaths, to: NSArray.self)
                guard let cfPaths = cfArray as? [String] else { return }
                let paths = Array(cfPaths.prefix(numEvents))

                monitor.handleFSEventsCallback(paths: paths)
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

    nonisolated func handleFSEventsCallback(paths: [String]) {
        Task {
            await self.scheduleDebounce(paths: paths)
        }
    }

    private func scheduleDebounce(paths: [String]) {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(500))
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

        await parseSettings()
        await parseStatsCache()
        await parseSessionHistories()
        await parsePlans()

        let errors = parseErrors
        let now = Date()
        let state = directoryState

        Task { @MainActor in
            state.errors = errors
            state.lastUpdated = now
        }
    }

    // MARK: - Individual parsers

    private func parseSettings() async {
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

    private func parseStatsCache() async {
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

    private func parseSessionHistories() async {
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

    private func parsePlans() async {
        let projectsURL = claudeDirectory.appendingPathComponent("projects")

        guard FileManager.default.fileExists(atPath: projectsURL.path) else {
            return
        }

        var updatedPlans: [String: [ClaudePlan]] = [:]

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
                guard FileManager.default.fileExists(atPath: plansDir.path) else { continue }

                let markdownFiles: [URL]
                do {
                    markdownFiles = try FileManager.default.contentsOfDirectory(
                        at: plansDir,
                        includingPropertiesForKeys: [.contentModificationDateKey],
                        options: .skipsHiddenFiles
                    ).filter { $0.pathExtension.lowercased() == "md" }
                } catch {
                    parseErrors.append(.parseError(plansDir.path, error))
                    continue
                }

                var projectPlans: [ClaudePlan] = []
                for file in markdownFiles {
                    do {
                        let content = try String(contentsOf: file, encoding: .utf8)
                        let attrs = try FileManager.default.attributesOfItem(atPath: file.path)
                        let modified = (attrs[.modificationDate] as? Date) ?? Date()
                        projectPlans.append(
                            ClaudePlan(
                                filePath: file.path,
                                content: content,
                                lastModified: modified
                            )
                        )
                    } catch {
                        parseErrors.append(.parseError(file.path, error))
                        Self.logger.error("Failed to read plan \(file.lastPathComponent): \(error)")
                    }
                }

                updatedPlans[projectDir.lastPathComponent] = projectPlans
            }
        } catch {
            parseErrors.append(.parseError(projectsURL.path, error))
            Self.logger.error("Failed to enumerate projects for plans: \(error)")
        }

        let plans = updatedPlans
        let state = directoryState
        Task { @MainActor in
            state.plans = plans
        }
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
