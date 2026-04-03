import Foundation
import Testing

@testable import ClaudeConfigKit

// MARK: - In-memory test store

final class InMemorySession: HookSessionRepresentable, @unchecked Sendable {
    let sessionId: String
    var workingDirectory: String
    var slug: String?
    var currentPhase: ClaudeSessionPhase

    init(sessionId: String, workingDirectory: String, phase: ClaudeSessionPhase = .idle) {
        self.sessionId = sessionId
        self.workingDirectory = workingDirectory
        self.currentPhase = phase
    }

    func setPhase(_ phase: ClaudeSessionPhase) {
        currentPhase = phase
    }
}

final class InMemorySessionStore: HookSessionStore, @unchecked Sendable {
    var sessions: [String: InMemorySession] = [:]

    func findSession(byId sessionId: String) async -> InMemorySession? {
        sessions[sessionId]
    }

    func createSession(sessionId: String, workingDirectory: String) async -> InMemorySession {
        let session = InMemorySession(sessionId: sessionId, workingDirectory: workingDirectory)
        sessions[sessionId] = session
        return session
    }

    func activeSessions() async -> [InMemorySession] {
        sessions.values.filter { $0.currentPhase != .stopped }
    }
}

// MARK: - Tests

@Suite("HookEventProcessorCore")
struct HookEventProcessorCoreTests {

    @Test("processEvent creates session when not found")
    func createsSession() async {
        let store = InMemorySessionStore()
        let processor = HookEventProcessorCore(store: store)

        let event = HookEvent(
            sessionId: "new-session",
            eventType: .sessionStart,
            workingDirectory: "/tmp/project"
        )

        let results = await processor.processEvent(event)

        #expect(results.contains(where: {
            if case .sessionCreated(let id) = $0 { return id == "new-session" }
            return false
        }))
        #expect(store.sessions["new-session"] != nil)
    }

    @Test("processEvent uses existing session")
    func usesExistingSession() async {
        let store = InMemorySessionStore()
        let existing = InMemorySession(sessionId: "abc", workingDirectory: "/tmp")
        store.sessions["abc"] = existing

        let processor = HookEventProcessorCore(store: store)

        let event = HookEvent(
            sessionId: "abc",
            eventType: .preToolUse,
            toolName: "Bash"
        )

        let results = await processor.processEvent(event)

        // Should NOT have sessionCreated
        #expect(!results.contains(where: {
            if case .sessionCreated = $0 { return true }
            return false
        }))

        // Should have phase change to toolExecuting
        #expect(existing.currentPhase == .toolExecuting)
    }

    @Test("processEvent applies phase change")
    func appliesPhaseChange() async {
        let store = InMemorySessionStore()
        let session = InMemorySession(sessionId: "abc", workingDirectory: "/tmp", phase: .idle)
        store.sessions["abc"] = session

        let processor = HookEventProcessorCore(store: store)

        let event = HookEvent(
            sessionId: "abc",
            eventType: .sessionEnd
        )

        let results = await processor.processEvent(event)

        #expect(session.currentPhase == .stopped)
        #expect(results.contains(where: {
            if case .phaseChanged(_, let oldPhase, let newPhase) = $0 {
                return oldPhase == .idle && newPhase == .stopped
            }
            return false
        }))
    }

    @Test("processEvent emits side effects")
    func emitsSideEffects() async {
        let store = InMemorySessionStore()
        let session = InMemorySession(sessionId: "abc", workingDirectory: "/tmp", phase: .processing)
        session.slug = "my-slug"
        store.sessions["abc"] = session

        let processor = HookEventProcessorCore(store: store)

        let event = HookEvent(
            sessionId: "abc",
            eventType: .preCompact
        )

        let results = await processor.processEvent(event)

        // PreCompact should invalidate slug
        #expect(session.slug == nil)

        #expect(results.contains(where: {
            if case .sideEffectApplied(_, let effect) = $0 {
                return effect == .invalidateSlug
            }
            return false
        }))
    }

    @Test("processEvent always emits eventProcessed")
    func alwaysEmitsEventProcessed() async {
        let store = InMemorySessionStore()
        let processor = HookEventProcessorCore(store: store)

        let event = HookEvent(
            sessionId: "abc",
            eventType: .taskCompleted
        )

        let results = await processor.processEvent(event)

        #expect(results.contains(where: {
            if case .eventProcessed = $0 { return true }
            return false
        }))
    }
}
