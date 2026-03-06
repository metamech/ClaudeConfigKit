import Foundation

// MARK: - HookEventType

/// Event types corresponding to Claude Code hook lifecycle events.
public enum HookEventType: String, Codable, Sendable {
    case preToolUse = "PreToolUse"
    case postToolUse = "PostToolUse"
    case postToolUseFailure = "PostToolUseFailure"
    case notification = "Notification"
    case stop = "Stop"
    case sessionStart = "SessionStart"
    case sessionEnd = "SessionEnd"
    case userPromptSubmit = "UserPromptSubmit"
    case permissionRequest = "PermissionRequest"
    case subagentStart = "SubagentStart"
    case subagentStop = "SubagentStop"
    case preCompact = "PreCompact"
    case configChange = "ConfigChange"
    case taskCompleted = "TaskCompleted"
    case teammateIdle = "TeammateIdle"
    case worktreeCreate = "WorktreeCreate"
    case worktreeRemove = "WorktreeRemove"
}

// MARK: - ClaudePermissionMode

/// The permission mode of a Claude Code session.
public enum ClaudePermissionMode: String, Codable, Sendable {
    case `default` = "default"
    case plan = "plan"
    case acceptEdits = "acceptEdits"
    case dontAsk = "dontAsk"
    case bypassPermissions = "bypassPermissions"
}

// MARK: - HookEvent

/// A single event received from a Claude Code hook script.
///
/// Claude Code invokes hook scripts at lifecycle boundaries (pre/post tool use,
/// notifications, session start/end). The generated hook scripts forward their
/// stdin payload as JSON, where it is decoded into a `HookEvent`.
///
/// The actual JSON from Claude Code uses `hook_event_name` (not `event_type`),
/// `cwd` (not `working_directory`), and does not include a `timestamp` field.
/// The `timestamp` is set at decode time. The `rawPayload` is set separately
/// after decoding and is excluded from `CodingKeys`.
public struct HookEvent: Sendable {

    public let sessionId: String
    public let eventType: HookEventType
    public let timestamp: Date
    public let toolName: String?
    public let toolInput: [String: AnyCodableValue]?
    public let workingDirectory: String?
    public let permissionMode: ClaudePermissionMode?
    public let sessionStartReason: String?
    public let sessionEndReason: String?
    public let subagentType: String?
    public let parentSessionId: String?
    public let exitCode: Int?
    public let compactionReason: String?
    public let configChangeType: String?
    public let worktreePath: String?
    public let tenrecSessionId: String?
    public let rawPayload: Data?

    public init(
        sessionId: String,
        eventType: HookEventType,
        timestamp: Date = Date(),
        toolName: String? = nil,
        toolInput: [String: AnyCodableValue]? = nil,
        workingDirectory: String? = nil,
        permissionMode: ClaudePermissionMode? = nil,
        sessionStartReason: String? = nil,
        sessionEndReason: String? = nil,
        subagentType: String? = nil,
        parentSessionId: String? = nil,
        exitCode: Int? = nil,
        compactionReason: String? = nil,
        configChangeType: String? = nil,
        worktreePath: String? = nil,
        tenrecSessionId: String? = nil,
        rawPayload: Data? = nil
    ) {
        self.sessionId = sessionId
        self.eventType = eventType
        self.timestamp = timestamp
        self.toolName = toolName
        self.toolInput = toolInput
        self.workingDirectory = workingDirectory
        self.permissionMode = permissionMode
        self.sessionStartReason = sessionStartReason
        self.sessionEndReason = sessionEndReason
        self.subagentType = subagentType
        self.parentSessionId = parentSessionId
        self.exitCode = exitCode
        self.compactionReason = compactionReason
        self.configChangeType = configChangeType
        self.worktreePath = worktreePath
        self.tenrecSessionId = tenrecSessionId
        self.rawPayload = rawPayload
    }
}

// MARK: - Codable

extension HookEvent: Codable {

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case eventType = "hook_event_name"
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case workingDirectory = "cwd"
        case permissionMode = "permission_mode"
        case sessionStartReason = "session_start_reason"
        case sessionEndReason = "session_end_reason"
        case subagentType = "subagent_type"
        case parentSessionId = "parent_session_id"
        case exitCode = "exit_code"
        case compactionReason = "compaction_reason"
        case configChangeType = "config_change_type"
        case worktreePath = "worktree_path"
        case tenrecSessionId = "tenrec_session_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        eventType = try container.decode(HookEventType.self, forKey: .eventType)
        toolName = try container.decodeIfPresent(String.self, forKey: .toolName)
        toolInput = try container.decodeIfPresent([String: AnyCodableValue].self, forKey: .toolInput)
        workingDirectory = try container.decodeIfPresent(String.self, forKey: .workingDirectory)
        permissionMode = try container.decodeIfPresent(ClaudePermissionMode.self, forKey: .permissionMode)
        sessionStartReason = try container.decodeIfPresent(String.self, forKey: .sessionStartReason)
        sessionEndReason = try container.decodeIfPresent(String.self, forKey: .sessionEndReason)
        subagentType = try container.decodeIfPresent(String.self, forKey: .subagentType)
        parentSessionId = try container.decodeIfPresent(String.self, forKey: .parentSessionId)
        exitCode = try container.decodeIfPresent(Int.self, forKey: .exitCode)
        compactionReason = try container.decodeIfPresent(String.self, forKey: .compactionReason)
        configChangeType = try container.decodeIfPresent(String.self, forKey: .configChangeType)
        worktreePath = try container.decodeIfPresent(String.self, forKey: .worktreePath)
        tenrecSessionId = try container.decodeIfPresent(String.self, forKey: .tenrecSessionId)
        timestamp = Date()
        rawPayload = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(eventType, forKey: .eventType)
        try container.encodeIfPresent(toolName, forKey: .toolName)
        try container.encodeIfPresent(toolInput, forKey: .toolInput)
        try container.encodeIfPresent(workingDirectory, forKey: .workingDirectory)
        try container.encodeIfPresent(permissionMode, forKey: .permissionMode)
        try container.encodeIfPresent(sessionStartReason, forKey: .sessionStartReason)
        try container.encodeIfPresent(sessionEndReason, forKey: .sessionEndReason)
        try container.encodeIfPresent(subagentType, forKey: .subagentType)
        try container.encodeIfPresent(parentSessionId, forKey: .parentSessionId)
        try container.encodeIfPresent(exitCode, forKey: .exitCode)
        try container.encodeIfPresent(compactionReason, forKey: .compactionReason)
        try container.encodeIfPresent(configChangeType, forKey: .configChangeType)
        try container.encodeIfPresent(worktreePath, forKey: .worktreePath)
        try container.encodeIfPresent(tenrecSessionId, forKey: .tenrecSessionId)
    }
}

// MARK: - AnyCodableValue

/// Type-erased JSON value used for tool input parameters whose schema is not
/// known at compile time.
public enum AnyCodableValue: Codable, Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodableValue])
    case object([String: AnyCodableValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let arr = try? container.decode([AnyCodableValue].self) {
            self = .array(arr)
        } else if let obj = try? container.decode([String: AnyCodableValue].self) {
            self = .object(obj)
        } else if container.decodeNil() {
            self = .null
        } else {
            self = .null
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s):  try container.encode(s)
        case .int(let i):     try container.encode(i)
        case .double(let d):  try container.encode(d)
        case .bool(let b):    try container.encode(b)
        case .array(let arr): try container.encode(arr)
        case .object(let obj): try container.encode(obj)
        case .null:           try container.encodeNil()
        }
    }
}
