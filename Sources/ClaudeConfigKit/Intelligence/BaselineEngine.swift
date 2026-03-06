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

// MARK: - BaselineEngine

/// Captures configuration baselines and detects changes against them.
public actor BaselineEngine {

    public init() {}

    /// Capture a baseline snapshot for the file at `url`.
    public func captureBaseline(for url: URL) throws -> ConfigBaseline {
        let data = try Data(contentsOf: url)
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
    public func detectChanges(for url: URL, against baseline: ConfigBaseline) throws -> ConfigChangeRecord? {
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

        let data = try Data(contentsOf: url)
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
            currentHash: currentHash
        )
    }

    // MARK: - Private

    private func extractSchema(from data: Data, url: URL) -> SchemaStructure {
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
