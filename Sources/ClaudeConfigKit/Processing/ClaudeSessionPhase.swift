import Foundation

/// Fine-grained phase of a Claude Code session, representing the current activity.
///
/// Captures 11 distinct phases — including compacting, tool failure, and permission
/// waiting — enabling richer UI and diagnostics.
public enum ClaudeSessionPhase: String, Codable, Sendable {
    /// Session just started (fresh launch).
    case freshStart
    /// Session resumed from a previous conversation.
    case resumed
    /// Session resumed after context compaction.
    case compacted
    /// User submitted a prompt; Claude is thinking.
    case processing
    /// A tool is currently executing (between PreToolUse and PostToolUse).
    case toolExecuting
    /// A tool just failed (transient — will return to processing).
    case toolFailed
    /// Claude is waiting for user input (idle notification).
    case waitingInput
    /// Claude is waiting for the user to approve a permission request.
    case waitingPermission
    /// Context compaction is in progress (overlay state).
    case compacting
    /// Session is idle (between prompts).
    case idle
    /// Session has ended.
    case stopped
}

/// Broad session status for consumers that don't need fine-grained phases.
public enum ClaudeSessionStatus: String, Codable, Sendable {
    case starting
    case running
    case waitingInput
    case idle
    case stopped
}

extension ClaudeSessionPhase {
    /// Maps this phase to the broad ``ClaudeSessionStatus``.
    public var legacyStatus: ClaudeSessionStatus {
        switch self {
        case .freshStart, .resumed, .compacted:
            return .starting
        case .processing, .toolExecuting, .toolFailed, .compacting:
            return .running
        case .waitingInput, .waitingPermission:
            return .waitingInput
        case .idle:
            return .idle
        case .stopped:
            return .stopped
        }
    }
}
