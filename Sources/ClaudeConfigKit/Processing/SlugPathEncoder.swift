import Foundation

// MARK: - SlugPathEncoder

/// Utilities for encoding paths and building URLs in Claude Code's project
/// directory naming convention.
///
/// Claude Code stores JSONL history files at:
/// ```
/// ~/.claude/projects/<encoded-cwd>/<sessionId>.jsonl
/// ```
/// where `<encoded-cwd>` replaces `/` with `-` and drops the leading `-`.
public enum SlugPathEncoder {

    /// Encode an absolute path into Claude Code's project directory name format.
    ///
    /// Replaces `/` with `-` and drops the leading `-`.
    /// Example: `/Users/ion/project` → `Users-ion-project`
    public static func encodeProjectPath(_ path: String) -> String {
        let encoded = path.replacingOccurrences(of: "/", with: "-")
        if encoded.hasPrefix("-") {
            return String(encoded.dropFirst())
        }
        return encoded
    }

    /// Build the file URL for a session's JSONL history file.
    ///
    /// - Parameters:
    ///   - sessionId: The Claude session ID (UUID string).
    ///   - workingDirectory: The absolute working directory path.
    /// - Returns: URL to `~/.claude/projects/<encoded>/<sessionId>.jsonl`.
    public static func jsonlFileURL(sessionId: String, workingDirectory: String) -> URL {
        let encoded = encodeProjectPath(workingDirectory)
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
            .appendingPathComponent(encoded)
            .appendingPathComponent("\(sessionId).jsonl")
    }
}
