import Foundation

// MARK: - ClaudeSettings

/// Codable representation of `~/.claude/settings.json`.
///
/// Uses lenient decoding: unknown keys are silently ignored, and all top-level
/// properties are optional so that fields added in future Claude Code versions
/// do not break the parser.
public struct ClaudeSettings: Codable, Sendable {
    /// Permission overrides keyed by tool or resource name.
    public var permissions: [String: PermissionSetting]?

    /// Environment variables injected into every Claude Code session.
    public var env: [String: String]?

    /// Hook definitions keyed by event name (e.g. `"PreToolUse"`, `"PostToolUse"`).
    public var hooks: [String: [HookMatcherGroup]]?

    /// MCP server definitions keyed by server name.
    public var mcpServers: [String: MCPServerEntry]?

    public init(
        permissions: [String: PermissionSetting]? = nil,
        env: [String: String]? = nil,
        hooks: [String: [HookMatcherGroup]]? = nil,
        mcpServers: [String: MCPServerEntry]? = nil
    ) {
        self.permissions = permissions
        self.env = env
        self.hooks = hooks
        self.mcpServers = mcpServers
    }
}

// MARK: - MCPServerEntry

/// An MCP server entry in settings.json.
public struct MCPServerEntry: Codable, Sendable, Equatable {
    /// Transport type (e.g. `"stdio"`).
    public var type: String?

    /// The command to execute.
    public var command: String?

    /// Optional command arguments.
    public var args: [String]?

    public init(type: String? = nil, command: String? = nil, args: [String]? = nil) {
        self.type = type
        self.command = command
        self.args = args
    }
}

// MARK: - PermissionSetting

/// A single permission entry in the `permissions` map.
public struct PermissionSetting: Codable, Sendable {
    /// The decision applied for this permission key: `"allow"` or `"deny"`.
    public var decision: String?

    public init(decision: String? = nil) {
        self.decision = decision
    }
}

// MARK: - HookMatcherGroup

/// A group of hooks that share a single glob/regex matcher.
public struct HookMatcherGroup: Codable, Sendable {
    /// Optional glob or regex pattern matched against the triggering tool name.
    public var matcher: String?

    /// The hook handlers to invoke when this group's matcher fires.
    public var hooks: [HookHandlerConfig]?

    public init(matcher: String? = nil, hooks: [HookHandlerConfig]? = nil) {
        self.matcher = matcher
        self.hooks = hooks
    }
}

// MARK: - HookHandlerConfig

/// Configuration for a single hook handler within a ``HookMatcherGroup``.
public struct HookHandlerConfig: Codable, Sendable {
    /// Handler dispatch type.  Known values: `"command"`, `"prompt"`, `"agent"`.
    public var type: String

    /// Shell command to execute (present when `type == "command"`).
    public var command: String?

    /// Prompt text to inject (present when `type == "prompt"`).
    public var prompt: String?

    /// Maximum time in seconds the hook may run before it is killed.
    public var timeout: Int?

    /// When `true` the hook is dispatched asynchronously.
    public var async: Bool?

    public init(
        type: String,
        command: String? = nil,
        prompt: String? = nil,
        timeout: Int? = nil,
        async: Bool? = nil
    ) {
        self.type = type
        self.command = command
        self.prompt = prompt
        self.timeout = timeout
        self.async = async
    }
}
