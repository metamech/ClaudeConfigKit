import Foundation

// MARK: - ClaudeDirectoryError

/// Errors that can occur while reading or parsing files inside `~/.claude`.
public enum ClaudeDirectoryError: Error, Sendable {
    /// The expected file was not found at `path`.
    case fileNotFound(String)

    /// The file at `path` could not be decoded.
    case parseError(String, any Error)

    /// The process does not have read permission for the file or directory at `path`.
    case accessDenied(String)
}

// MARK: - ClaudeDirectoryState

/// Observable snapshot of the parsed `~/.claude` directory, published on the
/// main actor for consumption by SwiftUI views and ViewModels.
///
/// ``ClaudeDirectoryMonitor`` is the sole writer; views and ViewModels are
/// read-only consumers.
@Observable @MainActor
public final class ClaudeDirectoryState {

    // MARK: - Parsed file contents

    public var settings: ClaudeSettings?
    public var statsCache: ClaudeStatsCache?

    // MARK: - Per-project collections

    public var sessionHistories: [String: [ClaudeSessionHistoryEntry]] = [:]
    public var plans: [String: [ClaudePlan]] = [:]

    // MARK: - Metadata

    public var lastUpdated: Date?
    public var errors: [ClaudeDirectoryError] = []

    public init() {}
}
