import Foundation

// MARK: - ChangeType

/// Classification of a detected configuration change.
public enum ChangeType: String, Codable, Sendable {
    /// The file's content changed but its structural schema remained the same.
    case dataChange

    /// The file's structural schema changed (e.g. new keys added, types changed).
    case schemaChange

    /// The file was newly created (no previous baseline existed).
    case fileAdded

    /// The file was removed (baseline exists but file is gone).
    case fileRemoved
}

// MARK: - ConfigChangeRecord

/// A record of a detected configuration change.
public struct ConfigChangeRecord: Sendable, Codable {
    /// Path to the changed file.
    public var filePath: String

    /// Classification of the change.
    public var changeType: ChangeType

    /// When the change was detected.
    public var timestamp: Date

    /// Human-readable summary of the change.
    public var summary: String

    /// Schema fingerprint before the change (nil for file additions).
    public var previousFingerprint: String?

    /// Schema fingerprint after the change (nil for file removals).
    public var currentFingerprint: String?

    /// Content hash before the change (nil for file additions).
    public var previousHash: String?

    /// Content hash after the change (nil for file removals).
    public var currentHash: String?

    public init(
        filePath: String,
        changeType: ChangeType,
        timestamp: Date = Date(),
        summary: String,
        previousFingerprint: String? = nil,
        currentFingerprint: String? = nil,
        previousHash: String? = nil,
        currentHash: String? = nil
    ) {
        self.filePath = filePath
        self.changeType = changeType
        self.timestamp = timestamp
        self.summary = summary
        self.previousFingerprint = previousFingerprint
        self.currentFingerprint = currentFingerprint
        self.previousHash = previousHash
        self.currentHash = currentHash
    }
}
