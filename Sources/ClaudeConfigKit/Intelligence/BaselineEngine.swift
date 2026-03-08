import Foundation

// MARK: - ConfigBaseline

/// A snapshot of a configuration file at a point in time.
public struct ConfigBaseline: Sendable, Codable, Equatable {
    /// Path to the file.
    public var filePath: String

    /// SHA-256 hash of the file's content.
    public var contentHash: String

    /// Structural schema extracted from the file.
    public var schema: SchemaStructure

    /// When this baseline was captured.
    public var capturedAt: Date

    public init(filePath: String, contentHash: String, schema: SchemaStructure, capturedAt: Date = Date()) {
        self.filePath = filePath
        self.contentHash = contentHash
        self.schema = schema
        self.capturedAt = capturedAt
    }
}

// MARK: - SymlinkPolicy

/// Policy for following symlinks during file discovery.
public enum SymlinkPolicy: Sendable {
    /// Follow all symlinks.
    case follow
    /// Follow symlinks only if they resolve within the search subtree.
    case withinSubtree
    /// Never follow symlinks.
    case never
}

// MARK: - BaselineEngine

/// Captures configuration baselines and detects changes against them.
public actor BaselineEngine {

    /// Default set of known config file names.
    public static let defaultKnownFiles: Set<String> = [
        "settings.json", "CLAUDE.md", "AGENTS.md", ".claude.json", "stats-cache.json"
    ]

    /// Default set of known config directory names.
    public static let defaultKnownDirs: Set<String> = [".claude"]

    public init() {}

    // MARK: - Single file operations

    /// Capture a baseline snapshot for the file at `url`.
    public func captureBaseline(for url: URL) async throws -> ConfigBaseline {
        let data = try await FileHasher.readFileData(at: url)
        let hash = FileHasher.hash(data: data)
        let schema = extractSchema(from: data, url: url)

        return ConfigBaseline(
            filePath: url.path,
            contentHash: hash,
            schema: schema
        )
    }

    /// Detect changes for the file at `url` compared to a previous baseline.
    ///
    /// Returns `nil` if the file has not changed. Returns a ``ConfigChangeRecord``
    /// describing the change if one is detected.
    public func detectChanges(for url: URL, against baseline: ConfigBaseline) async throws -> ConfigChangeRecord? {
        let fileExists = FileManager.default.fileExists(atPath: url.path)

        if !fileExists {
            return ConfigChangeRecord(
                filePath: baseline.filePath,
                changeType: .fileRemoved,
                summary: "File removed: \(url.lastPathComponent)",
                previousFingerprint: baseline.schema.fingerprint,
                previousHash: baseline.contentHash
            )
        }

        let data = try await FileHasher.readFileData(at: url)
        let currentHash = FileHasher.hash(data: data)

        // No change
        guard currentHash != baseline.contentHash else {
            return nil
        }

        let currentSchema = extractSchema(from: data, url: url)
        let changeType: ChangeType
        let summary: String

        if currentSchema.fingerprint != baseline.schema.fingerprint {
            changeType = .schemaChange
            summary = "Schema change detected in \(url.lastPathComponent)"
        } else {
            changeType = .dataChange
            summary = "Data change detected in \(url.lastPathComponent)"
        }

        return ConfigChangeRecord(
            filePath: url.path,
            changeType: changeType,
            summary: summary,
            previousFingerprint: baseline.schema.fingerprint,
            currentFingerprint: currentSchema.fingerprint,
            previousHash: baseline.contentHash,
            currentHash: currentHash,
            diffData: data
        )
    }

    // MARK: - Batch operations (Gap 7)

    /// Capture baselines for multiple files concurrently.
    public func captureBaselines(for urls: [URL]) async throws -> [ConfigBaseline] {
        try await withThrowingTaskGroup(of: ConfigBaseline.self, returning: [ConfigBaseline].self) { group in
            for url in urls {
                group.addTask {
                    let data = try await FileHasher.readFileData(at: url)
                    let hash = FileHasher.hash(data: data)
                    let schema = self.extractSchema(from: data, url: url)
                    return ConfigBaseline(
                        filePath: url.path,
                        contentHash: hash,
                        schema: schema
                    )
                }
            }
            var results: [ConfigBaseline] = []
            for try await baseline in group {
                results.append(baseline)
            }
            return results
        }
    }

    /// Detect changes for multiple file change events, deduplicating by path.
    public func detectChanges(
        for events: [FileChangeEvent],
        against baselines: [String: ConfigBaseline]
    ) async throws -> [ConfigChangeRecord] {
        // Deduplicate events by path
        var uniquePaths: [String: FileChangeEvent] = [:]
        for event in events {
            uniquePaths[event.path] = event
        }

        return try await withThrowingTaskGroup(of: ConfigChangeRecord?.self, returning: [ConfigChangeRecord].self) { group in
            for (path, _) in uniquePaths {
                let url = URL(fileURLWithPath: path)
                guard let baseline = baselines[path] else { continue }
                group.addTask {
                    try await self.detectChanges(for: url, against: baseline)
                }
            }
            var results: [ConfigChangeRecord] = []
            for try await record in group {
                if let record {
                    results.append(record)
                }
            }
            return results
        }
    }

    // MARK: - Baseline update (Gap 8)

    /// Update a baseline by re-capturing the file's current state.
    public func updateBaseline(_ baseline: ConfigBaseline, from url: URL) async throws -> ConfigBaseline {
        try await captureBaseline(for: url)
    }

    // MARK: - File discovery (Gap 6)

    /// Discover config files in a directory by matching known file names and scanning known directories.
    public func discoverConfigFiles(
        at directory: URL,
        knownFiles: Set<String> = BaselineEngine.defaultKnownFiles,
        knownDirs: Set<String> = BaselineEngine.defaultKnownDirs,
        followSymlinks: SymlinkPolicy = .withinSubtree
    ) async throws -> [URL] {
        let knownFilesCopy = knownFiles
        let knownDirsCopy = knownDirs
        let policy = followSymlinks
        return try await Task.detached(priority: .utility) {
            try Self.performDiscovery(
                at: directory,
                knownFiles: knownFilesCopy,
                knownDirs: knownDirsCopy,
                followSymlinks: policy
            )
        }.value
    }

    private static func performDiscovery(
        at directory: URL,
        knownFiles: Set<String>,
        knownDirs: Set<String>,
        followSymlinks: SymlinkPolicy
    ) throws -> [URL] {
        var discovered: [URL] = []
        let fm = FileManager.default
        let realDirectory = directory.resolvingSymlinksInPath()

        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        while let fileURL = enumerator.nextObject() as? URL {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey])

            // Handle symlink policy
            if resourceValues.isSymbolicLink == true {
                switch followSymlinks {
                case .never:
                    enumerator.skipDescendants()
                    continue
                case .withinSubtree:
                    let resolved = fileURL.resolvingSymlinksInPath()
                    if !resolved.path.hasPrefix(realDirectory.path) {
                        enumerator.skipDescendants()
                        continue
                    }
                case .follow:
                    break
                }
            }

            let fileName = fileURL.lastPathComponent

            if resourceValues.isRegularFile == true {
                if knownFiles.contains(fileName) {
                    discovered.append(fileURL)
                }
            }

            if resourceValues.isDirectory == true {
                if knownDirs.contains(fileName) {
                    // Scan all files in known dirs
                    if let subEnumerator = fm.enumerator(
                        at: fileURL,
                        includingPropertiesForKeys: [.isRegularFileKey],
                        options: []
                    ) {
                        while let subFile = subEnumerator.nextObject() as? URL {
                            let subValues = try subFile.resourceValues(forKeys: [.isRegularFileKey])
                            if subValues.isRegularFile == true {
                                discovered.append(subFile)
                            }
                        }
                    }
                    enumerator.skipDescendants()
                }
            }
        }

        return discovered
    }

    // MARK: - Private

    nonisolated private func extractSchema(from data: Data, url: URL) -> SchemaStructure {
        let ext = url.pathExtension.lowercased()
        if ext == "json" || ext == "jsonl" {
            return (try? SchemaExtractor.extractJSON(from: data)) ?? SchemaStructure()
        } else if ext == "md" || ext == "markdown" {
            let content = String(data: data, encoding: .utf8) ?? ""
            return SchemaExtractor.extractMarkdown(from: content)
        }
        return SchemaStructure()
    }
}
