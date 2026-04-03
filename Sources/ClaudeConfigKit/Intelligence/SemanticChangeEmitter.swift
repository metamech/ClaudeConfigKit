import Foundation

// MARK: - SemanticConfigChange

/// A high-level, domain-specific configuration change event.
///
/// Replaces raw file-system events with semantic changes that consuming
/// applications can act on directly without parsing the diff themselves.
public enum SemanticConfigChange: Sendable, Equatable {
    /// An MCP server was added.
    case mcpServerAdded(name: String)

    /// An MCP server was removed.
    case mcpServerRemoved(name: String)

    /// An MCP server's configuration was updated.
    case mcpServerUpdated(name: String)

    /// A hook event group was installed (new event name appeared).
    case hookInstalled(event: String)

    /// A hook event group was removed (event name disappeared).
    case hookRemoved(event: String)

    /// A hook event group was modified (handlers changed).
    case hookUpdated(event: String)

    /// A permission entry was added or changed.
    case permissionChanged(key: String, decision: String?)

    /// A permission entry was removed.
    case permissionRemoved(key: String)

    /// An environment variable was added or changed.
    case envChanged(key: String)

    /// An environment variable was removed.
    case envRemoved(key: String)
}

// MARK: - SemanticChangeEmitter

/// Diffs `ClaudeSettings` snapshots and emits semantic change events.
///
/// Wire this as a downstream consumer of `ClaudeDirectoryState.settings`
/// changes to get high-level change events instead of raw file events.
///
/// ```swift
/// let emitter = SemanticChangeEmitter()
/// let changes = emitter.processSettingsUpdate(newSettings)
/// for change in changes {
///     // e.g. .mcpServerAdded(name: "tenrec")
/// }
/// ```
public struct SemanticChangeEmitter: Sendable {

    private var previousSettings: ClaudeSettings?

    public init() {}

    /// Compare new settings against the previous snapshot and return semantic changes.
    ///
    /// Updates the internal snapshot to `newSettings` after diffing.
    public mutating func processSettingsUpdate(
        _ newSettings: ClaudeSettings
    ) -> [SemanticConfigChange] {
        let previous = previousSettings ?? ClaudeSettings()
        previousSettings = newSettings

        var changes: [SemanticConfigChange] = []

        diffMCPServers(previous: previous, current: newSettings, into: &changes)
        diffHooks(previous: previous, current: newSettings, into: &changes)
        diffPermissions(previous: previous, current: newSettings, into: &changes)
        diffEnv(previous: previous, current: newSettings, into: &changes)

        return changes
    }

    /// Reset the internal snapshot, treating the next update as a fresh baseline.
    public mutating func reset() {
        previousSettings = nil
    }

    // MARK: - Private diffing

    private func diffMCPServers(
        previous: ClaudeSettings,
        current: ClaudeSettings,
        into changes: inout [SemanticConfigChange]
    ) {
        let oldServers = previous.mcpServers ?? [:]
        let newServers = current.mcpServers ?? [:]

        for name in newServers.keys where oldServers[name] == nil {
            changes.append(.mcpServerAdded(name: name))
        }

        for name in oldServers.keys where newServers[name] == nil {
            changes.append(.mcpServerRemoved(name: name))
        }

        for name in newServers.keys {
            if let oldEntry = oldServers[name], let newEntry = newServers[name],
               oldEntry != newEntry {
                changes.append(.mcpServerUpdated(name: name))
            }
        }
    }

    private func diffHooks(
        previous: ClaudeSettings,
        current: ClaudeSettings,
        into changes: inout [SemanticConfigChange]
    ) {
        let oldHooks = previous.hooks ?? [:]
        let newHooks = current.hooks ?? [:]

        for event in newHooks.keys where oldHooks[event] == nil {
            changes.append(.hookInstalled(event: event))
        }

        for event in oldHooks.keys where newHooks[event] == nil {
            changes.append(.hookRemoved(event: event))
        }

        for event in newHooks.keys {
            guard let oldGroups = oldHooks[event], let newGroups = newHooks[event] else {
                continue
            }
            if !hookGroupsEqual(oldGroups, newGroups) {
                changes.append(.hookUpdated(event: event))
            }
        }
    }

    private func diffPermissions(
        previous: ClaudeSettings,
        current: ClaudeSettings,
        into changes: inout [SemanticConfigChange]
    ) {
        let oldPerms = previous.permissions ?? [:]
        let newPerms = current.permissions ?? [:]

        for (key, newPerm) in newPerms {
            let oldPerm = oldPerms[key]
            if oldPerm?.decision != newPerm.decision {
                changes.append(.permissionChanged(key: key, decision: newPerm.decision))
            }
        }

        for key in oldPerms.keys where newPerms[key] == nil {
            changes.append(.permissionRemoved(key: key))
        }
    }

    private func diffEnv(
        previous: ClaudeSettings,
        current: ClaudeSettings,
        into changes: inout [SemanticConfigChange]
    ) {
        let oldEnv = previous.env ?? [:]
        let newEnv = current.env ?? [:]

        for (key, value) in newEnv where oldEnv[key] != value {
            changes.append(.envChanged(key: key))
        }

        for key in oldEnv.keys where newEnv[key] == nil {
            changes.append(.envRemoved(key: key))
        }
    }

    // MARK: - Helpers

    private func hookGroupsEqual(
        _ lhs: [HookMatcherGroup],
        _ rhs: [HookMatcherGroup]
    ) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (l, r) in zip(lhs, rhs) {
            guard l.matcher == r.matcher else { return false }
            let lHooks = l.hooks ?? []
            let rHooks = r.hooks ?? []
            guard lHooks.count == rHooks.count else { return false }
            for (lh, rh) in zip(lHooks, rHooks) {
                guard lh.type == rh.type,
                      lh.command == rh.command,
                      lh.prompt == rh.prompt,
                      lh.timeout == rh.timeout,
                      lh.async == rh.async else {
                    return false
                }
            }
        }
        return true
    }
}
