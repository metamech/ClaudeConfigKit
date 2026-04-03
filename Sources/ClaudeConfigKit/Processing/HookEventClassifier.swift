import Foundation

// MARK: - HookEventCategory

/// High-level category for a hook event, used to route processing.
public enum HookEventCategory: Sendable {
    /// Session lifecycle events (start, end, stop).
    case sessionLifecycle
    /// Tool use events (pre/post tool use, failures).
    case toolUse
    /// Notification events (waiting for input, etc.).
    case notification
    /// Permission-related events.
    case permission
    /// Context compaction events.
    case compaction
    /// Subagent events.
    case subagent
    /// Configuration change events.
    case configChange
    /// Informational events with no state changes.
    case informational
}

// MARK: - HookEventClassifier

/// Pure function that classifies a ``HookEvent`` into processing categories.
public enum HookEventClassifier {

    /// Classify a hook event by its type.
    public static func classify(_ event: HookEvent) -> HookEventCategory {
        classify(event.eventType)
    }

    /// Classify a hook event type.
    public static func classify(_ eventType: HookEventType) -> HookEventCategory {
        switch eventType {
        case .sessionStart, .sessionEnd, .stop:
            return .sessionLifecycle
        case .preToolUse, .postToolUse, .postToolUseFailure:
            return .toolUse
        case .notification:
            return .notification
        case .permissionRequest, .userPromptSubmit:
            return .permission
        case .preCompact:
            return .compaction
        case .subagentStart, .subagentStop:
            return .subagent
        case .configChange:
            return .configChange
        case .taskCompleted, .teammateIdle, .worktreeCreate, .worktreeRemove:
            return .informational
        }
    }
}
