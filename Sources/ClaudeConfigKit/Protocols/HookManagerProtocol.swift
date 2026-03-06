import Foundation

// MARK: - HookManagerProtocol

/// Protocol adopted by services that register Claude Code hooks and listen for
/// incoming hook events over a Unix domain socket.
///
/// Conforming types are `Actor`s so all state mutations are automatically
/// serialised.  The protocol exposes only the minimal surface required for
/// lifecycle management and event consumption.
public protocol HookManagerProtocol: Actor {

    /// Register hooks in `~/.claude/settings.json`.
    func registerHooks() async throws

    /// Remove all owned hook entries from `~/.claude/settings.json`.
    func unregisterHooks() async throws

    /// Start listening for incoming hook events on the Unix domain socket.
    func startListening() async throws

    /// Stop the Unix domain socket listener and cancel any in-flight connection tasks.
    func stopListening() async

    /// An `AsyncStream` of ``HookEvent`` values published as they arrive.
    var eventStream: AsyncStream<HookEvent> { get }

    /// `true` while the Unix domain socket listener is active.
    var isListening: Bool { get }
}

// MARK: - HookManagerError

/// Errors thrown by ``HookManagerProtocol`` implementations.
public enum HookManagerError: Error, CustomStringConvertible, Sendable {
    /// The Application Support directory could not be located.
    case supportDirectoryNotFound

    /// A directory or file could not be created at the given path.
    case fileSystemError(String, any Error)

    /// `~/.claude/settings.json` could not be read.
    case settingsReadFailed(any Error)

    /// `~/.claude/settings.json` could not be written.
    case settingsWriteFailed(any Error)

    /// The Unix domain socket could not be created (`errno` is included).
    case socketCreateFailed(Int32)

    /// The socket could not be bound to its path (`errno` is included).
    case socketBindFailed(Int32)

    /// The socket could not begin listening (`errno` is included).
    case socketListenFailed(Int32)

    public var description: String {
        switch self {
        case .supportDirectoryNotFound:
            return "Application Support directory not found"
        case .fileSystemError(let path, let error):
            return "File system error at \(path): \(error)"
        case .settingsReadFailed(let error):
            return "Failed to read settings.json: \(error)"
        case .settingsWriteFailed(let error):
            return "Failed to write settings.json: \(error)"
        case .socketCreateFailed(let errno):
            return "socket() failed with errno \(errno)"
        case .socketBindFailed(let errno):
            return "bind() failed with errno \(errno)"
        case .socketListenFailed(let errno):
            return "listen() failed with errno \(errno)"
        }
    }
}
