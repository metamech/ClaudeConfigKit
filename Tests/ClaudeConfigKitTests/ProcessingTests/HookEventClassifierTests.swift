import Foundation
import Testing

@testable import ClaudeConfigKit

@Suite("HookEventClassifier")
struct HookEventClassifierTests {

    @Test("SessionStart is sessionLifecycle")
    func sessionStart() {
        #expect(HookEventClassifier.classify(.sessionStart) == .sessionLifecycle)
    }

    @Test("SessionEnd is sessionLifecycle")
    func sessionEnd() {
        #expect(HookEventClassifier.classify(.sessionEnd) == .sessionLifecycle)
    }

    @Test("Stop is sessionLifecycle")
    func stop() {
        #expect(HookEventClassifier.classify(.stop) == .sessionLifecycle)
    }

    @Test("PreToolUse is toolUse")
    func preToolUse() {
        #expect(HookEventClassifier.classify(.preToolUse) == .toolUse)
    }

    @Test("PostToolUse is toolUse")
    func postToolUse() {
        #expect(HookEventClassifier.classify(.postToolUse) == .toolUse)
    }

    @Test("Notification is notification")
    func notification() {
        #expect(HookEventClassifier.classify(.notification) == .notification)
    }

    @Test("PermissionRequest is permission")
    func permissionRequest() {
        #expect(HookEventClassifier.classify(.permissionRequest) == .permission)
    }

    @Test("PreCompact is compaction")
    func preCompact() {
        #expect(HookEventClassifier.classify(.preCompact) == .compaction)
    }

    @Test("SubagentStart is subagent")
    func subagentStart() {
        #expect(HookEventClassifier.classify(.subagentStart) == .subagent)
    }

    @Test("ConfigChange is configChange")
    func configChange() {
        #expect(HookEventClassifier.classify(.configChange) == .configChange)
    }

    @Test("TaskCompleted is informational")
    func taskCompleted() {
        #expect(HookEventClassifier.classify(.taskCompleted) == .informational)
    }

    @Test("Classifies HookEvent directly")
    func classifyEvent() {
        let event = HookEvent(sessionId: "abc", eventType: .preToolUse, toolName: "Bash")
        #expect(HookEventClassifier.classify(event) == .toolUse)
    }
}
