import Foundation

// MARK: - SessionPhaseSideEffect

/// Mutations that a phase transition can request beyond changing the phase itself.
///
/// The state machine returns these alongside the new phase; the caller is
/// responsible for applying them to the session model.
public enum SessionPhaseSideEffect: Equatable, Sendable {
    /// Set `isCompacting` to the given value.
    case setCompacting(Bool)
    /// Set `lastToolName` to the given value (nil clears it).
    case setToolName(String?)
    /// Set `lastPermissionRequestAt` to the current date.
    case recordPermissionRequest
    /// Set `sessionStartReason` to the given string.
    case setSessionStartReason(String)
    /// Increment `activeSubagentCount` by 1.
    case incrementSubagentCount
    /// Decrement `activeSubagentCount` by 1 (floored at 0).
    case decrementSubagentCount
    /// Set the permission mode to the given value.
    case setPermissionMode(ClaudePermissionMode)
    /// Invalidate the slug cache for this session (compaction creates a new ID).
    case invalidateSlug
}

// MARK: - SessionPhaseTransition

/// The output of a single state-machine step.
public struct SessionPhaseTransition: Equatable, Sendable {
    /// The phase to move to.  Nil means "no phase change".
    public let newPhase: ClaudeSessionPhase?
    /// Side effects the caller must apply after the phase change.
    public let sideEffects: [SessionPhaseSideEffect]

    public init(newPhase: ClaudeSessionPhase?, sideEffects: [SessionPhaseSideEffect]) {
        self.newPhase = newPhase
        self.sideEffects = sideEffects
    }
}

// MARK: - NotificationPayload

/// Decoded fields from a `notification` hook event payload, used by the
/// state machine to decide whether to enter `.waitingInput`.
public struct NotificationPayload: Equatable, Sendable {
    public let title: String
    public let type: String
    public let message: String
    public let waitingForInput: Bool
    public let toolName: String?

    public init(
        title: String = "",
        type: String = "",
        message: String = "",
        waitingForInput: Bool = false,
        toolName: String? = nil
    ) {
        self.title = title
        self.type = type
        self.message = message
        self.waitingForInput = waitingForInput
        self.toolName = toolName
    }

    /// Keyword list used for heuristic "waiting for input" detection.
    public static let inputKeywords: [String] = [
        "waiting", "question", "ready", "prompt", "confirm", "choose", "select", "respond",
    ]

    /// Returns true if the payload signals that Claude is waiting for user input.
    public var isWaitingForInput: Bool {
        if waitingForInput { return true }
        let lowerType = type.lowercased()
        if lowerType.contains("input") { return true }
        let lowerTitle = title.lowercased()
        let lowerMessage = message.lowercased()
        let toolLower = toolName?.lowercased() ?? ""
        if toolLower.contains("user_input") || toolLower.contains("waiting") || toolLower.contains("input_needed") {
            return true
        }
        return Self.inputKeywords.contains(where: {
            lowerTitle.contains($0) || lowerMessage.contains($0)
        })
    }
}

// MARK: - SessionPhaseStateMachine

/// Pure value-type state machine for ``ClaudeSessionPhase`` transitions.
///
/// Given the current phase, an incoming ``HookEventType``, and any relevant
/// payload data, `step(currentPhase:eventType:payload:)` returns the new phase
/// and a list of ``SessionPhaseSideEffect`` values to apply.  The machine has
/// no dependencies on SwiftData, `@MainActor`, or any UI framework.
///
/// ```swift
/// let transition = SessionPhaseStateMachine.step(
///     currentPhase: session.currentPhase,
///     eventType: event.eventType,
///     payload: .init(from: event)
/// )
/// if let newPhase = transition.newPhase {
///     session.setPhase(newPhase)
/// }
/// for effect in transition.sideEffects {
///     apply(effect, to: session)
/// }
/// ```
public struct SessionPhaseStateMachine {

    // MARK: - EventPayload

    /// The subset of ``HookEvent`` fields the machine needs for decisions.
    public struct EventPayload: Equatable, Sendable {
        public let sessionStartReason: String?
        public let toolName: String?
        public let permissionMode: ClaudePermissionMode?
        public let notification: NotificationPayload?

        public init(
            sessionStartReason: String? = nil,
            toolName: String? = nil,
            permissionMode: ClaudePermissionMode? = nil,
            notification: NotificationPayload? = nil
        ) {
            self.sessionStartReason = sessionStartReason
            self.toolName = toolName
            self.permissionMode = permissionMode
            self.notification = notification
        }
    }

    // MARK: - Core step function

    /// Advance the state machine by one event.
    public static func step(
        currentPhase: ClaudeSessionPhase,
        eventType: HookEventType,
        payload: EventPayload
    ) -> SessionPhaseTransition {
        switch eventType {

        case .sessionStart:
            return handleSessionStart(payload: payload)

        case .userPromptSubmit:
            return SessionPhaseTransition(newPhase: .processing, sideEffects: [])

        case .preToolUse:
            let effects: [SessionPhaseSideEffect] = [.setToolName(payload.toolName)]
            return SessionPhaseTransition(newPhase: .toolExecuting, sideEffects: effects)

        case .postToolUse:
            let effects: [SessionPhaseSideEffect] = [.setToolName(payload.toolName)]
            return SessionPhaseTransition(newPhase: .processing, sideEffects: effects)

        case .postToolUseFailure:
            let effects: [SessionPhaseSideEffect] = [.setToolName(payload.toolName)]
            return SessionPhaseTransition(newPhase: .processing, sideEffects: effects)

        case .permissionRequest:
            return SessionPhaseTransition(
                newPhase: .waitingPermission,
                sideEffects: [.recordPermissionRequest]
            )

        case .notification:
            return handleNotification(payload: payload)

        case .preCompact:
            return SessionPhaseTransition(
                newPhase: nil,
                sideEffects: [.setCompacting(true), .invalidateSlug]
            )

        case .stop:
            return SessionPhaseTransition(
                newPhase: .idle,
                sideEffects: [.setCompacting(false)]
            )

        case .sessionEnd:
            return SessionPhaseTransition(
                newPhase: .stopped,
                sideEffects: [.setCompacting(false)]
            )

        case .subagentStart:
            return SessionPhaseTransition(newPhase: nil, sideEffects: [.incrementSubagentCount])

        case .subagentStop:
            return SessionPhaseTransition(newPhase: nil, sideEffects: [.decrementSubagentCount])

        case .configChange:
            if let mode = payload.permissionMode {
                return SessionPhaseTransition(newPhase: nil, sideEffects: [.setPermissionMode(mode)])
            }
            return SessionPhaseTransition(newPhase: nil, sideEffects: [])

        case .taskCompleted, .teammateIdle, .worktreeCreate, .worktreeRemove:
            return SessionPhaseTransition(newPhase: nil, sideEffects: [])
        }
    }

    // MARK: - Private helpers

    private static func handleSessionStart(payload: EventPayload) -> SessionPhaseTransition {
        let reason = payload.sessionStartReason ?? "startup"
        let newPhase: ClaudeSessionPhase
        switch reason {
        case "resume":  newPhase = .resumed
        case "compact": newPhase = .compacted
        default:        newPhase = .freshStart
        }
        return SessionPhaseTransition(
            newPhase: newPhase,
            sideEffects: [.setSessionStartReason(reason)]
        )
    }

    private static func handleNotification(payload: EventPayload) -> SessionPhaseTransition {
        guard let notification = payload.notification else {
            return SessionPhaseTransition(newPhase: nil, sideEffects: [])
        }
        if notification.isWaitingForInput {
            return SessionPhaseTransition(newPhase: .waitingInput, sideEffects: [])
        }
        return SessionPhaseTransition(newPhase: nil, sideEffects: [])
    }
}

// MARK: - HookEvent convenience initialiser

extension SessionPhaseStateMachine.EventPayload {
    /// Build a payload from a live ``HookEvent``.
    ///
    /// Decodes `rawPayload` here so the state machine core stays free of JSON
    /// parsing.
    public init(from event: HookEvent) {
        self.sessionStartReason = event.sessionStartReason
        self.toolName = event.toolName
        self.permissionMode = event.permissionMode

        if event.eventType == .notification {
            var notif = NotificationPayload(toolName: event.toolName)
            if let rawPayload = event.rawPayload,
               let json = try? JSONSerialization.jsonObject(with: rawPayload) as? [String: Any] {
                notif = NotificationPayload(
                    title: (json["title"] as? String) ?? "",
                    type: (json["type"] as? String) ?? "",
                    message: (json["message"] as? String) ?? "",
                    waitingForInput: (json["waitingForInput"] as? Bool) ?? false,
                    toolName: event.toolName
                )
            }
            self.notification = notif
        } else {
            self.notification = nil
        }
    }
}
