import Foundation

// MARK: - ClaudeSettingsWriter

/// Atomic, merge-aware writer for `~/.claude/settings.json`.
///
/// Uses raw JSON passthrough (not Codable round-tripping) to preserve
/// unknown keys added by future Claude Code versions.
///
/// ```swift
/// let writer = ClaudeSettingsWriter()
/// try await writer.addMCPServer(
///     name: "tenrec",
///     config: MCPServerConfig(type: "stdio", command: "/path/to/bridge")
/// )
/// ```
public actor ClaudeSettingsWriter {

    private let settingsURL: URL

    /// Creates a settings writer.
    ///
    /// - Parameter settingsURL: Override for the settings file path.
    ///   Defaults to `~/.claude/settings.json`.
    public init(settingsURL: URL? = nil) {
        self.settingsURL = settingsURL ?? Self.defaultSettingsURL()
    }

    // MARK: - MCP Server Management

    /// Adds or updates an MCP server entry.
    public func addMCPServer(name: String, config: MCPServerConfig) throws {
        try modify { root in
            var servers = root["mcpServers"] as? [String: Any] ?? [:]
            var entry: [String: Any] = [
                "type": config.type,
                "command": config.command,
            ]
            if let args = config.args { entry["args"] = args }
            if let env = config.env { entry["env"] = env }
            servers[name] = entry
            root["mcpServers"] = servers
        }
    }

    /// Removes an MCP server entry by name.
    public func removeMCPServer(name: String) throws {
        try modify { root in
            guard var servers = root["mcpServers"] as? [String: Any] else { return }
            servers.removeValue(forKey: name)
            if servers.isEmpty {
                root.removeValue(forKey: "mcpServers")
            } else {
                root["mcpServers"] = servers
            }
        }
    }

    // MARK: - Hook Management

    /// Adds a hook handler to the specified event and matcher group.
    ///
    /// If a group with the same matcher already exists, the handler is appended.
    /// Otherwise a new group is created.
    public func addHook(
        event: String,
        matcher: String?,
        handler: HookHandlerConfig
    ) throws {
        try modify { root in
            var hooks = root["hooks"] as? [String: Any] ?? [:]
            var groups = hooks[event] as? [[String: Any]] ?? []

            let matcherKey = matcher ?? ""
            var found = false
            for i in groups.indices {
                let groupMatcher = groups[i]["matcher"] as? String ?? ""
                if groupMatcher == matcherKey {
                    var handlerList = groups[i]["hooks"] as? [[String: Any]] ?? []
                    handlerList.append(Self.encodeHandler(handler))
                    groups[i]["hooks"] = handlerList
                    found = true
                    break
                }
            }

            if !found {
                var group: [String: Any] = [
                    "hooks": [Self.encodeHandler(handler)]
                ]
                if let matcher { group["matcher"] = matcher }
                groups.append(group)
            }

            hooks[event] = groups
            root["hooks"] = hooks
        }
    }

    /// Removes hook handlers matching the predicate across all events and groups.
    public func removeHooks(
        matching predicate: @Sendable (HookHandlerConfig) -> Bool
    ) throws {
        try modify { root in
            guard var hooks = root["hooks"] as? [String: Any] else { return }

            for (event, value) in hooks {
                guard var groups = value as? [[String: Any]] else { continue }
                for i in groups.indices {
                    guard let handlerDicts = groups[i]["hooks"] as? [[String: Any]] else {
                        continue
                    }
                    let filtered = handlerDicts.filter { dict in
                        guard let config = Self.decodeHandler(dict) else { return true }
                        return !predicate(config)
                    }
                    groups[i]["hooks"] = filtered
                }
                // Remove empty groups
                groups.removeAll { group in
                    (group["hooks"] as? [[String: Any]])?.isEmpty ?? true
                }
                if groups.isEmpty {
                    hooks.removeValue(forKey: event)
                } else {
                    hooks[event] = groups
                }
            }

            if hooks.isEmpty {
                root.removeValue(forKey: "hooks")
            } else {
                root["hooks"] = hooks
            }
        }
    }

    // MARK: - Generic Modify

    /// Performs an atomic read-modify-write cycle on the raw settings JSON.
    ///
    /// Use this for custom mutations that the convenience methods do not cover.
    public func modify(
        _ transform: (inout [String: Any]) throws -> Void
    ) throws {
        var root = try readRawJSON()
        try transform(&root)
        try writeRawJSON(root)
    }

    // MARK: - Private

    private func readRawJSON() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            return [:]
        }
        let data = try Data(contentsOf: settingsURL)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    private func writeRawJSON(_ root: [String: Any]) throws {
        let dir = settingsURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true
            )
        }
        let data = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: settingsURL, options: .atomic)
    }

    private static func defaultSettingsURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
            .appendingPathComponent("settings.json")
    }

    private static func encodeHandler(_ config: HookHandlerConfig) -> [String: Any] {
        var dict: [String: Any] = ["type": config.type]
        if let command = config.command { dict["command"] = command }
        if let prompt = config.prompt { dict["prompt"] = prompt }
        if let timeout = config.timeout { dict["timeout"] = timeout }
        if let isAsync = config.async { dict["async"] = isAsync }
        return dict
    }

    private static func decodeHandler(_ dict: [String: Any]) -> HookHandlerConfig? {
        guard let type = dict["type"] as? String else { return nil }
        return HookHandlerConfig(
            type: type,
            command: dict["command"] as? String,
            prompt: dict["prompt"] as? String,
            timeout: dict["timeout"] as? Int,
            async: dict["async"] as? Bool
        )
    }
}
