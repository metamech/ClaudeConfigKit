import Foundation
import Testing

@testable import ClaudeConfigKit

// MARK: - SemanticChangeEmitterTests

@Suite("SemanticChangeEmitter")
struct SemanticChangeEmitterTests {

    // MARK: - MCP Server changes

    @Test("Detects MCP server added")
    func mcpServerAdded() {
        var emitter = SemanticChangeEmitter()

        // First call establishes baseline
        _ = emitter.processSettingsUpdate(ClaudeSettings())

        // Second call adds a server
        let settings = ClaudeSettings(
            mcpServers: ["tenrec": MCPServerEntry(type: "stdio", command: "/bin/bridge")]
        )
        let changes = emitter.processSettingsUpdate(settings)

        #expect(changes.contains(.mcpServerAdded(name: "tenrec")))
    }

    @Test("Detects MCP server removed")
    func mcpServerRemoved() {
        var emitter = SemanticChangeEmitter()

        let initial = ClaudeSettings(
            mcpServers: ["tenrec": MCPServerEntry(type: "stdio", command: "/bin/bridge")]
        )
        _ = emitter.processSettingsUpdate(initial)

        let updated = ClaudeSettings()
        let changes = emitter.processSettingsUpdate(updated)

        #expect(changes.contains(.mcpServerRemoved(name: "tenrec")))
    }

    @Test("Detects MCP server updated")
    func mcpServerUpdated() {
        var emitter = SemanticChangeEmitter()

        let initial = ClaudeSettings(
            mcpServers: ["tenrec": MCPServerEntry(type: "stdio", command: "/old/path")]
        )
        _ = emitter.processSettingsUpdate(initial)

        let updated = ClaudeSettings(
            mcpServers: ["tenrec": MCPServerEntry(type: "stdio", command: "/new/path")]
        )
        let changes = emitter.processSettingsUpdate(updated)

        #expect(changes.contains(.mcpServerUpdated(name: "tenrec")))
    }

    @Test("No change when server unchanged")
    func mcpServerUnchanged() {
        var emitter = SemanticChangeEmitter()

        let entry = MCPServerEntry(type: "stdio", command: "/bin/bridge")
        let settings = ClaudeSettings(mcpServers: ["tenrec": entry])
        _ = emitter.processSettingsUpdate(settings)

        let changes = emitter.processSettingsUpdate(settings)
        #expect(changes.isEmpty)
    }

    // MARK: - Hook changes

    @Test("Detects hook installed")
    func hookInstalled() {
        var emitter = SemanticChangeEmitter()
        _ = emitter.processSettingsUpdate(ClaudeSettings())

        let settings = ClaudeSettings(
            hooks: ["PreToolUse": [HookMatcherGroup(
                matcher: "Bash",
                hooks: [HookHandlerConfig(type: "command", command: "/bin/check")]
            )]]
        )
        let changes = emitter.processSettingsUpdate(settings)

        #expect(changes.contains(.hookInstalled(event: "PreToolUse")))
    }

    @Test("Detects hook removed")
    func hookRemoved() {
        var emitter = SemanticChangeEmitter()

        let initial = ClaudeSettings(
            hooks: ["PreToolUse": [HookMatcherGroup(
                hooks: [HookHandlerConfig(type: "command", command: "/bin/check")]
            )]]
        )
        _ = emitter.processSettingsUpdate(initial)

        let changes = emitter.processSettingsUpdate(ClaudeSettings())
        #expect(changes.contains(.hookRemoved(event: "PreToolUse")))
    }

    @Test("Detects hook updated when handler changes")
    func hookUpdated() {
        var emitter = SemanticChangeEmitter()

        let initial = ClaudeSettings(
            hooks: ["PreToolUse": [HookMatcherGroup(
                hooks: [HookHandlerConfig(type: "command", command: "/bin/old")]
            )]]
        )
        _ = emitter.processSettingsUpdate(initial)

        let updated = ClaudeSettings(
            hooks: ["PreToolUse": [HookMatcherGroup(
                hooks: [HookHandlerConfig(type: "command", command: "/bin/new")]
            )]]
        )
        let changes = emitter.processSettingsUpdate(updated)

        #expect(changes.contains(.hookUpdated(event: "PreToolUse")))
    }

    // MARK: - Permission changes

    @Test("Detects permission added")
    func permissionAdded() {
        var emitter = SemanticChangeEmitter()
        _ = emitter.processSettingsUpdate(ClaudeSettings())

        let settings = ClaudeSettings(
            permissions: ["Bash": PermissionSetting(decision: "allow")]
        )
        let changes = emitter.processSettingsUpdate(settings)

        #expect(changes.contains(.permissionChanged(key: "Bash", decision: "allow")))
    }

    @Test("Detects permission changed")
    func permissionChanged() {
        var emitter = SemanticChangeEmitter()

        let initial = ClaudeSettings(
            permissions: ["Bash": PermissionSetting(decision: "allow")]
        )
        _ = emitter.processSettingsUpdate(initial)

        let updated = ClaudeSettings(
            permissions: ["Bash": PermissionSetting(decision: "deny")]
        )
        let changes = emitter.processSettingsUpdate(updated)

        #expect(changes.contains(.permissionChanged(key: "Bash", decision: "deny")))
    }

    @Test("Detects permission removed")
    func permissionRemoved() {
        var emitter = SemanticChangeEmitter()

        let initial = ClaudeSettings(
            permissions: ["Bash": PermissionSetting(decision: "allow")]
        )
        _ = emitter.processSettingsUpdate(initial)

        let changes = emitter.processSettingsUpdate(ClaudeSettings())
        #expect(changes.contains(.permissionRemoved(key: "Bash")))
    }

    // MARK: - Environment changes

    @Test("Detects env variable added")
    func envAdded() {
        var emitter = SemanticChangeEmitter()
        _ = emitter.processSettingsUpdate(ClaudeSettings())

        let settings = ClaudeSettings(env: ["LOG_LEVEL": "debug"])
        let changes = emitter.processSettingsUpdate(settings)

        #expect(changes.contains(.envChanged(key: "LOG_LEVEL")))
    }

    @Test("Detects env variable changed")
    func envChanged() {
        var emitter = SemanticChangeEmitter()

        let initial = ClaudeSettings(env: ["LOG_LEVEL": "info"])
        _ = emitter.processSettingsUpdate(initial)

        let updated = ClaudeSettings(env: ["LOG_LEVEL": "debug"])
        let changes = emitter.processSettingsUpdate(updated)

        #expect(changes.contains(.envChanged(key: "LOG_LEVEL")))
    }

    @Test("Detects env variable removed")
    func envRemoved() {
        var emitter = SemanticChangeEmitter()

        let initial = ClaudeSettings(env: ["LOG_LEVEL": "debug"])
        _ = emitter.processSettingsUpdate(initial)

        let changes = emitter.processSettingsUpdate(ClaudeSettings())
        #expect(changes.contains(.envRemoved(key: "LOG_LEVEL")))
    }

    // MARK: - Reset

    @Test("reset treats next update as fresh baseline")
    func resetBaseline() {
        var emitter = SemanticChangeEmitter()

        let settings = ClaudeSettings(env: ["KEY": "val"])
        _ = emitter.processSettingsUpdate(settings)

        emitter.reset()

        // After reset, same settings should show changes (compared to empty baseline)
        let changes = emitter.processSettingsUpdate(settings)
        #expect(changes.contains(.envChanged(key: "KEY")))
    }

    // MARK: - First update

    @Test("First update with non-empty settings detects additions")
    func firstUpdateDetectsAll() {
        var emitter = SemanticChangeEmitter()

        let settings = ClaudeSettings(
            permissions: ["Bash": PermissionSetting(decision: "allow")],
            env: ["KEY": "val"],
            hooks: ["PreToolUse": [HookMatcherGroup(
                hooks: [HookHandlerConfig(type: "command", command: "/bin/check")]
            )]],
            mcpServers: ["tenrec": MCPServerEntry(type: "stdio")]
        )
        let changes = emitter.processSettingsUpdate(settings)

        #expect(changes.contains(.mcpServerAdded(name: "tenrec")))
        #expect(changes.contains(.hookInstalled(event: "PreToolUse")))
        #expect(changes.contains(.permissionChanged(key: "Bash", decision: "allow")))
        #expect(changes.contains(.envChanged(key: "KEY")))
    }
}
