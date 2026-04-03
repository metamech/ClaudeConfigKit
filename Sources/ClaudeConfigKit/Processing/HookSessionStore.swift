import Foundation

// MARK: - HookSessionRepresentable

/// Protocol for session objects that the generic hook event processor can
/// manipulate without knowledge of the concrete persistence layer.
public protocol HookSessionRepresentable: AnyObject, Sendable {
    /// The Claude Code session identifier.
    var sessionId: String { get }

    /// The working directory for this session.
    var workingDirectory: String { get set }

    /// The cached slug, if resolved.
    var slug: String? { get set }

    /// The current phase of this session.
    var currentPhase: ClaudeSessionPhase { get }

    /// Transition to a new phase.
    func setPhase(_ phase: ClaudeSessionPhase)
}

// MARK: - HookSessionStore

/// Protocol abstracting the persistence layer for hook event processing.
///
/// Implement this protocol to bridge the generic ``HookEventProcessorCore``
/// with your persistence layer (e.g. SwiftData, in-memory, Core Data).
public protocol HookSessionStore: Sendable {
    associatedtype Session: HookSessionRepresentable

    /// Find an existing session by Claude session ID.
    func findSession(byId sessionId: String) async -> Session?

    /// Create a new session with the given ID and working directory.
    func createSession(sessionId: String, workingDirectory: String) async -> Session

    /// Return all sessions that are not in the `.stopped` phase.
    func activeSessions() async -> [Session]
}
