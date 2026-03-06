import Foundation

// MARK: - ClaudePlan

/// A Markdown plan file found under `~/.claude/projects/<encoded-path>/plans/`.
///
/// Plan files are plain Markdown — they are not JSON — so this is a plain
/// value type rather than `Codable`.  The monitor service reads the raw file
/// contents and wraps them in a ``ClaudePlan`` instance.
public struct ClaudePlan: Sendable {

    /// Absolute path to the `.md` file on disk.
    public var filePath: String

    /// Raw Markdown content of the plan file.
    public var content: String

    /// Modification date reported by the file-system at the time of last read.
    public var lastModified: Date

    public init(filePath: String, content: String, lastModified: Date) {
        self.filePath = filePath
        self.content = content
        self.lastModified = lastModified
    }
}
