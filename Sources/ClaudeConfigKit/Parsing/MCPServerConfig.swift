import Foundation

// MARK: - MCPServerConfig

/// Configuration for an MCP server entry in `~/.claude/settings.json`.
public struct MCPServerConfig: Codable, Sendable, Equatable {

    /// Transport type (e.g. `"stdio"`).
    public var type: String

    /// The command to execute.
    public var command: String

    /// Optional command arguments.
    public var args: [String]?

    /// Optional environment variables.
    public var env: [String: String]?

    public init(
        type: String,
        command: String,
        args: [String]? = nil,
        env: [String: String]? = nil
    ) {
        self.type = type
        self.command = command
        self.args = args
        self.env = env
    }
}
