import Foundation
import Testing

@testable import ClaudeConfigKit

// MARK: - ClaudeSettingsWriter Tests

@Suite("ClaudeSettingsWriter")
struct ClaudeSettingsWriterTests {

    // MARK: - Helper

    private func makeTempURL() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClaudeSettingsWriterTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("settings.json")
    }

    private func readJSON(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    // MARK: - MCP Server Tests

    @Test("addMCPServer creates file if absent")
    func addServerCreatesFile() async throws {
        let url = try makeTempURL()
        // Ensure file does not exist
        try? FileManager.default.removeItem(at: url)

        let writer = ClaudeSettingsWriter(settingsURL: url)
        try await writer.addMCPServer(
            name: "tenrec",
            config: MCPServerConfig(type: "stdio", command: "/usr/bin/bridge")
        )

        let root = try readJSON(at: url)
        let servers = root["mcpServers"] as? [String: Any]
        #expect(servers != nil)
        let entry = servers?["tenrec"] as? [String: Any]
        #expect(entry?["type"] as? String == "stdio")
        #expect(entry?["command"] as? String == "/usr/bin/bridge")
    }

    @Test("addMCPServer preserves existing entries")
    func addServerPreservesExisting() async throws {
        let url = try makeTempURL()
        let writer = ClaudeSettingsWriter(settingsURL: url)

        try await writer.addMCPServer(
            name: "alpha",
            config: MCPServerConfig(type: "stdio", command: "/bin/alpha")
        )
        try await writer.addMCPServer(
            name: "beta",
            config: MCPServerConfig(type: "stdio", command: "/bin/beta")
        )

        let root = try readJSON(at: url)
        let servers = root["mcpServers"] as? [String: Any]
        #expect(servers?.count == 2)
        #expect((servers?["alpha"] as? [String: Any])?["command"] as? String == "/bin/alpha")
        #expect((servers?["beta"] as? [String: Any])?["command"] as? String == "/bin/beta")
    }

    @Test("addMCPServer updates existing entry with same name")
    func addServerUpdatesExisting() async throws {
        let url = try makeTempURL()
        let writer = ClaudeSettingsWriter(settingsURL: url)

        try await writer.addMCPServer(
            name: "tenrec",
            config: MCPServerConfig(type: "stdio", command: "/old/path")
        )
        try await writer.addMCPServer(
            name: "tenrec",
            config: MCPServerConfig(type: "stdio", command: "/new/path")
        )

        let root = try readJSON(at: url)
        let servers = root["mcpServers"] as? [String: Any]
        #expect(servers?.count == 1)
        #expect((servers?["tenrec"] as? [String: Any])?["command"] as? String == "/new/path")
    }

    @Test("addMCPServer includes args and env when provided")
    func addServerWithArgsAndEnv() async throws {
        let url = try makeTempURL()
        let writer = ClaudeSettingsWriter(settingsURL: url)

        try await writer.addMCPServer(
            name: "tenrec",
            config: MCPServerConfig(
                type: "stdio",
                command: "/bin/bridge",
                args: ["--socket", "/tmp/mcp.sock"],
                env: ["LOG_LEVEL": "debug"]
            )
        )

        let root = try readJSON(at: url)
        let entry = (root["mcpServers"] as? [String: Any])?["tenrec"] as? [String: Any]
        #expect(entry?["args"] as? [String] == ["--socket", "/tmp/mcp.sock"])
        let env = entry?["env"] as? [String: String]
        #expect(env?["LOG_LEVEL"] == "debug")
    }

    @Test("removeMCPServer leaves other servers intact")
    func removeServerLeavesOthers() async throws {
        let url = try makeTempURL()
        let writer = ClaudeSettingsWriter(settingsURL: url)

        try await writer.addMCPServer(
            name: "alpha",
            config: MCPServerConfig(type: "stdio", command: "/bin/alpha")
        )
        try await writer.addMCPServer(
            name: "beta",
            config: MCPServerConfig(type: "stdio", command: "/bin/beta")
        )
        try await writer.removeMCPServer(name: "alpha")

        let root = try readJSON(at: url)
        let servers = root["mcpServers"] as? [String: Any]
        #expect(servers?.count == 1)
        #expect(servers?["alpha"] == nil)
        #expect(servers?["beta"] != nil)
    }

    @Test("removeMCPServer removes mcpServers key when empty")
    func removeServerCleansUpEmpty() async throws {
        let url = try makeTempURL()
        let writer = ClaudeSettingsWriter(settingsURL: url)

        try await writer.addMCPServer(
            name: "only",
            config: MCPServerConfig(type: "stdio", command: "/bin/only")
        )
        try await writer.removeMCPServer(name: "only")

        let root = try readJSON(at: url)
        #expect(root["mcpServers"] == nil)
    }

    @Test("removeMCPServer is a no-op when server does not exist")
    func removeServerNoOp() async throws {
        let url = try makeTempURL()
        let writer = ClaudeSettingsWriter(settingsURL: url)

        try await writer.addMCPServer(
            name: "alpha",
            config: MCPServerConfig(type: "stdio", command: "/bin/alpha")
        )
        try await writer.removeMCPServer(name: "nonexistent")

        let root = try readJSON(at: url)
        let servers = root["mcpServers"] as? [String: Any]
        #expect(servers?.count == 1)
    }

    // MARK: - Hook Tests

    @Test("addHook creates new event and group")
    func addHookNewEvent() async throws {
        let url = try makeTempURL()
        let writer = ClaudeSettingsWriter(settingsURL: url)

        try await writer.addHook(
            event: "PreToolUse",
            matcher: "Bash",
            handler: HookHandlerConfig(type: "command", command: "/bin/check")
        )

        let root = try readJSON(at: url)
        let hooks = root["hooks"] as? [String: Any]
        let groups = hooks?["PreToolUse"] as? [[String: Any]]
        #expect(groups?.count == 1)
        #expect(groups?[0]["matcher"] as? String == "Bash")
        let handlers = groups?[0]["hooks"] as? [[String: Any]]
        #expect(handlers?.count == 1)
        #expect(handlers?[0]["command"] as? String == "/bin/check")
    }

    @Test("addHook appends to existing matcher group")
    func addHookAppendsToGroup() async throws {
        let url = try makeTempURL()
        let writer = ClaudeSettingsWriter(settingsURL: url)

        try await writer.addHook(
            event: "PreToolUse",
            matcher: "Bash",
            handler: HookHandlerConfig(type: "command", command: "/bin/first")
        )
        try await writer.addHook(
            event: "PreToolUse",
            matcher: "Bash",
            handler: HookHandlerConfig(type: "command", command: "/bin/second")
        )

        let root = try readJSON(at: url)
        let groups = (root["hooks"] as? [String: Any])?["PreToolUse"] as? [[String: Any]]
        #expect(groups?.count == 1)
        let handlers = groups?[0]["hooks"] as? [[String: Any]]
        #expect(handlers?.count == 2)
    }

    @Test("addHook with nil matcher creates group without matcher key")
    func addHookNilMatcher() async throws {
        let url = try makeTempURL()
        let writer = ClaudeSettingsWriter(settingsURL: url)

        try await writer.addHook(
            event: "PostToolUse",
            matcher: nil,
            handler: HookHandlerConfig(type: "command", command: "/bin/log")
        )

        let root = try readJSON(at: url)
        let groups = (root["hooks"] as? [String: Any])?["PostToolUse"] as? [[String: Any]]
        #expect(groups?.count == 1)
        #expect(groups?[0]["matcher"] == nil)
    }

    @Test("removeHooks filters matching handlers")
    func removeHooksFilters() async throws {
        let url = try makeTempURL()
        let writer = ClaudeSettingsWriter(settingsURL: url)

        try await writer.addHook(
            event: "PreToolUse",
            matcher: nil,
            handler: HookHandlerConfig(type: "command", command: "/bin/keep")
        )
        try await writer.addHook(
            event: "PreToolUse",
            matcher: nil,
            handler: HookHandlerConfig(type: "command", command: "/bin/remove")
        )

        try await writer.removeHooks { config in
            config.command == "/bin/remove"
        }

        let root = try readJSON(at: url)
        let groups = (root["hooks"] as? [String: Any])?["PreToolUse"] as? [[String: Any]]
        let handlers = groups?[0]["hooks"] as? [[String: Any]]
        #expect(handlers?.count == 1)
        #expect(handlers?[0]["command"] as? String == "/bin/keep")
    }

    @Test("removeHooks cleans up empty groups and events")
    func removeHooksCleansUp() async throws {
        let url = try makeTempURL()
        let writer = ClaudeSettingsWriter(settingsURL: url)

        try await writer.addHook(
            event: "PreToolUse",
            matcher: nil,
            handler: HookHandlerConfig(type: "command", command: "/bin/only")
        )

        try await writer.removeHooks { _ in true }

        let root = try readJSON(at: url)
        #expect(root["hooks"] == nil)
    }

    // MARK: - Unknown key preservation

    @Test("Unknown keys survive round-trip")
    func unknownKeysPreserved() async throws {
        let url = try makeTempURL()

        // Seed with an unknown key
        let seed: [String: Any] = [
            "customFutureKey": ["nested": true],
            "permissions": ["Bash": ["decision": "allow"]],
        ]
        let data = try JSONSerialization.data(withJSONObject: seed, options: [.prettyPrinted])
        try data.write(to: url)

        let writer = ClaudeSettingsWriter(settingsURL: url)
        try await writer.addMCPServer(
            name: "tenrec",
            config: MCPServerConfig(type: "stdio", command: "/bin/bridge")
        )

        let root = try readJSON(at: url)
        // Unknown key must survive
        let custom = root["customFutureKey"] as? [String: Any]
        #expect(custom?["nested"] as? Bool == true)
        // Original key must survive
        #expect(root["permissions"] != nil)
        // New key must exist
        #expect(root["mcpServers"] != nil)
    }

    // MARK: - Empty file handling

    @Test("Reading from nonexistent file returns empty dict")
    func readMissingFile() async throws {
        let url = try makeTempURL()
        try? FileManager.default.removeItem(at: url)

        let writer = ClaudeSettingsWriter(settingsURL: url)
        // modify with no-op just to exercise readRawJSON
        try await writer.modify { _ in }

        // File should now exist (empty object)
        let root = try readJSON(at: url)
        #expect(root.isEmpty)
    }

    // MARK: - Generic modify

    @Test("modify allows custom mutations")
    func genericModify() async throws {
        let url = try makeTempURL()
        let writer = ClaudeSettingsWriter(settingsURL: url)

        try await writer.modify { root in
            root["customKey"] = "customValue"
        }

        let root = try readJSON(at: url)
        #expect(root["customKey"] as? String == "customValue")
    }
}
