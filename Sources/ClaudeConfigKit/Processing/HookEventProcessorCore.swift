import Foundation

// MARK: - HookProcessingEvent

/// Events emitted by ``HookEventProcessorCore`` after processing.
public enum HookProcessingEvent: Sendable {
    /// A session phase changed.
    case phaseChanged(sessionId: String, oldPhase: ClaudeSessionPhase, newPhase: ClaudeSessionPhase)
    /// A side effect was applied.
    case sideEffectApplied(sessionId: String, effect: SessionPhaseSideEffect)
    /// A new session was created.
    case sessionCreated(sessionId: String)
    /// An event was processed (for downstream handlers).
    case eventProcessed(HookEvent)
}

// MARK: - HookEventProcessorCore

/// Generic event processor parameterized by a session store.
///
/// Implements the core flow: receive event → classify → find/create session
/// via store → apply state machine → emit processing events.
///
/// Has no SwiftData, no `@MainActor`, and no handler pipeline — those
/// concerns belong to the consuming application.
///
/// ```swift
/// let store = MySwiftDataSessionStore(context: modelContext)
/// let processor = HookEventProcessorCore(store: store)
/// for await event in hookEventStream {
///     let results = await processor.processEvent(event)
///     for result in results {
///         // handle phase changes, side effects, etc.
///     }
/// }
/// ```
public actor HookEventProcessorCore<Store: HookSessionStore> {

    private let store: Store

    public init(store: Store) {
        self.store = store
    }

    /// Process a single hook event through the state machine.
    ///
    /// - Returns: Processing events describing what happened.
    public func processEvent(_ event: HookEvent) async -> [HookProcessingEvent] {
        var results: [HookProcessingEvent] = []

        // Find or create session
        let session: Store.Session
        if let existing = await store.findSession(byId: event.sessionId) {
            session = existing
        } else {
            session = await store.createSession(
                sessionId: event.sessionId,
                workingDirectory: event.workingDirectory ?? ""
            )
            results.append(.sessionCreated(sessionId: event.sessionId))
        }

        // Run state machine
        let payload = SessionPhaseStateMachine.EventPayload(from: event)
        let transition = SessionPhaseStateMachine.step(
            currentPhase: session.currentPhase,
            eventType: event.eventType,
            payload: payload
        )

        // Apply phase change
        if let newPhase = transition.newPhase {
            let oldPhase = session.currentPhase
            session.setPhase(newPhase)
            results.append(.phaseChanged(
                sessionId: event.sessionId,
                oldPhase: oldPhase,
                newPhase: newPhase
            ))
        }

        // Apply side effects
        for effect in transition.sideEffects {
            applySideEffect(effect, to: session)
            results.append(.sideEffectApplied(sessionId: event.sessionId, effect: effect))
        }

        results.append(.eventProcessed(event))
        return results
    }

    // MARK: - Private

    private func applySideEffect(_ effect: SessionPhaseSideEffect, to session: Store.Session) {
        switch effect {
        case .invalidateSlug:
            session.slug = nil
        case .setCompacting, .setToolName, .recordPermissionRequest,
             .setSessionStartReason, .incrementSubagentCount,
             .decrementSubagentCount, .setPermissionMode:
            // These side effects require properties not in HookSessionRepresentable.
            // The consuming application should handle them by inspecting the
            // .sideEffectApplied processing event.
            break
        }
    }
}
