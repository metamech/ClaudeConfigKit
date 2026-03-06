import Foundation

// MARK: - CodingAgentDirectoryMonitor

/// Protocol adopted by services that watch a coding-agent's working directory
/// for file-system changes and surface parsed state to the UI layer.
///
/// Conforming types are `Actor`s so all state mutations are automatically
/// serialised.  The protocol requires only the minimal surface needed for
/// lifecycle management; richer observation APIs are exposed on concrete types.
public protocol CodingAgentDirectoryMonitor: Actor {

    /// Begin watching the target directory and performing an initial full parse.
    ///
    /// Calling this when the monitor is already running is a no-op.
    func startMonitoring() async

    /// Stop watching the target directory and cancel any pending work.
    ///
    /// Calling this when the monitor is not running is a no-op.
    func stopMonitoring() async

    /// `true` while an active file-system watch is in place.
    var isMonitoring: Bool { get }
}
