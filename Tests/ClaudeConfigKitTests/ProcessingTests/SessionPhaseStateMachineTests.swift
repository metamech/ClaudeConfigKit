import Foundation
import Testing

@testable import ClaudeConfigKit

@Suite("SessionPhaseStateMachine")
struct SessionPhaseStateMachineTests {

    // MARK: - Session Start

    @Test("SessionStart with default reason → freshStart")
    func sessionStartDefault() {
        let transition = SessionPhaseStateMachine.step(
            currentPhase: .idle,
            eventType: .sessionStart,
            payload: .init()
        )
        #expect(transition.newPhase == .freshStart)
        #expect(transition.sideEffects.contains(.setSessionStartReason("startup")))
    }

    @Test("SessionStart with resume reason → resumed")
    func sessionStartResume() {
        let transition = SessionPhaseStateMachine.step(
            currentPhase: .idle,
            eventType: .sessionStart,
            payload: .init(sessionStartReason: "resume")
        )
        #expect(transition.newPhase == .resumed)
    }

    @Test("SessionStart with compact reason → compacted")
    func sessionStartCompact() {
        let transition = SessionPhaseStateMachine.step(
            currentPhase: .idle,
            eventType: .sessionStart,
            payload: .init(sessionStartReason: "compact")
        )
        #expect(transition.newPhase == .compacted)
    }

    // MARK: - Tool Use

    @Test("PreToolUse → toolExecuting with setToolName")
    func preToolUse() {
        let transition = SessionPhaseStateMachine.step(
            currentPhase: .processing,
            eventType: .preToolUse,
            payload: .init(toolName: "Bash")
        )
        #expect(transition.newPhase == .toolExecuting)
        #expect(transition.sideEffects.contains(.setToolName("Bash")))
    }

    @Test("PostToolUse → processing")
    func postToolUse() {
        let transition = SessionPhaseStateMachine.step(
            currentPhase: .toolExecuting,
            eventType: .postToolUse,
            payload: .init(toolName: "Bash")
        )
        #expect(transition.newPhase == .processing)
    }

    @Test("PostToolUseFailure → processing")
    func postToolUseFailure() {
        let transition = SessionPhaseStateMachine.step(
            currentPhase: .toolExecuting,
            eventType: .postToolUseFailure,
            payload: .init(toolName: "Bash")
        )
        #expect(transition.newPhase == .processing)
    }

    // MARK: - Notifications

    @Test("Notification with waitingForInput → waitingInput")
    func notificationWaitingInput() {
        let transition = SessionPhaseStateMachine.step(
            currentPhase: .processing,
            eventType: .notification,
            payload: .init(notification: NotificationPayload(waitingForInput: true))
        )
        #expect(transition.newPhase == .waitingInput)
    }

    @Test("Notification without input signal → no phase change")
    func notificationNoInput() {
        let transition = SessionPhaseStateMachine.step(
            currentPhase: .processing,
            eventType: .notification,
            payload: .init(notification: NotificationPayload(title: "Progress", message: "Working..."))
        )
        #expect(transition.newPhase == nil)
    }

    @Test("Notification with input keyword in title → waitingInput")
    func notificationKeywordDetection() {
        let transition = SessionPhaseStateMachine.step(
            currentPhase: .processing,
            eventType: .notification,
            payload: .init(notification: NotificationPayload(title: "Waiting for response"))
        )
        #expect(transition.newPhase == .waitingInput)
    }

    // MARK: - Permission & Prompt

    @Test("PermissionRequest → waitingPermission")
    func permissionRequest() {
        let transition = SessionPhaseStateMachine.step(
            currentPhase: .processing,
            eventType: .permissionRequest,
            payload: .init()
        )
        #expect(transition.newPhase == .waitingPermission)
        #expect(transition.sideEffects.contains(.recordPermissionRequest))
    }

    @Test("UserPromptSubmit → processing")
    func userPromptSubmit() {
        let transition = SessionPhaseStateMachine.step(
            currentPhase: .idle,
            eventType: .userPromptSubmit,
            payload: .init()
        )
        #expect(transition.newPhase == .processing)
    }

    // MARK: - Lifecycle

    @Test("Stop → idle")
    func stopEvent() {
        let transition = SessionPhaseStateMachine.step(
            currentPhase: .processing,
            eventType: .stop,
            payload: .init()
        )
        #expect(transition.newPhase == .idle)
    }

    @Test("SessionEnd → stopped")
    func sessionEnd() {
        let transition = SessionPhaseStateMachine.step(
            currentPhase: .idle,
            eventType: .sessionEnd,
            payload: .init()
        )
        #expect(transition.newPhase == .stopped)
    }

    // MARK: - Compaction

    @Test("PreCompact sets compacting flag and invalidates slug")
    func preCompact() {
        let transition = SessionPhaseStateMachine.step(
            currentPhase: .processing,
            eventType: .preCompact,
            payload: .init()
        )
        #expect(transition.newPhase == nil)
        #expect(transition.sideEffects.contains(.setCompacting(true)))
        #expect(transition.sideEffects.contains(.invalidateSlug))
    }

    // MARK: - Subagents

    @Test("SubagentStart increments count")
    func subagentStart() {
        let transition = SessionPhaseStateMachine.step(
            currentPhase: .processing,
            eventType: .subagentStart,
            payload: .init()
        )
        #expect(transition.newPhase == nil)
        #expect(transition.sideEffects.contains(.incrementSubagentCount))
    }

    // MARK: - Config change

    @Test("ConfigChange with permission mode sets it")
    func configChangePermission() {
        let transition = SessionPhaseStateMachine.step(
            currentPhase: .processing,
            eventType: .configChange,
            payload: .init(permissionMode: .plan)
        )
        #expect(transition.newPhase == nil)
        #expect(transition.sideEffects.contains(.setPermissionMode(.plan)))
    }

    // MARK: - EventPayload from HookEvent

    @Test("EventPayload from HookEvent extracts fields")
    func eventPayloadFromHookEvent() {
        let event = HookEvent(
            sessionId: "abc",
            eventType: .preToolUse,
            toolName: "Read",
            permissionMode: .default,
            sessionStartReason: nil
        )
        let payload = SessionPhaseStateMachine.EventPayload(from: event)
        #expect(payload.toolName == "Read")
        #expect(payload.permissionMode == .default)
        #expect(payload.notification == nil)
    }
}
