import Foundation
import Testing

@testable import ClaudeConfigKit

// MARK: - Claude Settings Parsing Tests

@Suite("Claude Settings Parsing")
struct ClaudeSettingsParsingTests {

    // MARK: - Helper

    func loadFixture(named name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures") else {
            throw URLError(.fileDoesNotExist)
        }
        return try Data(contentsOf: url)
    }

    // MARK: - Parse valid settings fixture

    @Test("Parse valid settings.json fixture with all fields populated")
    func parseValidSettingsFull() throws {
        let data = try loadFixture(named: "sample-settings.json")
        let decoder = JSONDecoder()
        let settings = try decoder.decode(ClaudeSettings.self, from: data)

        #expect(settings.permissions != nil)
        #expect(settings.permissions?.count == 2)
        #expect(settings.permissions?["Bash"]?.decision == "deny")
        #expect(settings.permissions?["Read"]?.decision == "allow")

        #expect(settings.env != nil)
        #expect(settings.env?.count == 3)
        #expect(settings.env?["NODE_ENV"] == "development")
        #expect(settings.env?["DEBUG"] == "true")
        #expect(settings.env?["CUSTOM_VAR"] == "custom_value")

        #expect(settings.hooks != nil)
        #expect(settings.hooks?.count == 3)

        let preToolUseGroups = settings.hooks?["PreToolUse"]
        #expect(preToolUseGroups?.count == 2)
        #expect(preToolUseGroups?[0].matcher == "Bash")
        #expect(preToolUseGroups?[0].hooks?.count == 1)
        #expect(preToolUseGroups?[0].hooks?[0].type == "command")
        #expect(preToolUseGroups?[0].hooks?[0].command == ".claude/hooks/validate-bash.sh")
        #expect(preToolUseGroups?[0].hooks?[0].timeout == 10)
        #expect(preToolUseGroups?[0].hooks?[0].async == false)

        #expect(preToolUseGroups?[1].matcher == nil)
        #expect(preToolUseGroups?[1].hooks?[0].type == "prompt")
        #expect(preToolUseGroups?[1].hooks?[0].prompt == "Review the tool usage")
        #expect(preToolUseGroups?[1].hooks?[0].async == true)

        let postToolUseGroups = settings.hooks?["PostToolUse"]
        #expect(postToolUseGroups?[0].hooks?[0].command == ".claude/hooks/post-tool.sh")
        #expect(postToolUseGroups?[0].hooks?[0].timeout == 30)

        let notificationGroups = settings.hooks?["Notification"]
        #expect(notificationGroups?[0].matcher == "Read|Glob|Grep")
        #expect(notificationGroups?[0].hooks?[0].type == "agent")
    }

    // MARK: - Parse settings with unknown keys

    @Test("Parse settings.json with unknown keys — known fields parsed")
    func parseSettingsWithUnknownKeys() throws {
        let jsonWithUnknownKeys = """
        {
            "permissions": {
                "Bash": {"decision": "deny"}
            },
            "env": {"KEY": "value"},
            "unknownTopLevel": {"some": "data"},
            "anotherUnknown": 42,
            "hooks": {
                "PreToolUse": [
                    {
                        "matcher": "Test",
                        "hooks": [
                            {
                                "type": "command",
                                "command": "test.sh",
                                "unknownField": "ignored"
                            }
                        ],
                        "unknownHookField": true
                    }
                ]
            }
        }
        """

        let decoder = JSONDecoder()
        let data = jsonWithUnknownKeys.data(using: .utf8)!
        let settings = try decoder.decode(ClaudeSettings.self, from: data)

        #expect(settings.permissions?["Bash"]?.decision == "deny")
        #expect(settings.env?["KEY"] == "value")
        #expect(settings.hooks?["PreToolUse"] != nil)
    }

    // MARK: - Parse malformed JSON

    @Test("Parse malformed JSON — returns error")
    func parseMalformedJSON() throws {
        let malformedData = try loadFixture(named: "malformed-settings.json")
        let decoder = JSONDecoder()

        #expect(throws: DecodingError.self) {
            try decoder.decode(ClaudeSettings.self, from: malformedData)
        }
    }

    // MARK: - Parse partial settings

    @Test("Parse partial settings.json — missing optional fields use defaults")
    func parsePartialSettings() throws {
        let data = try loadFixture(named: "partial-settings.json")
        let decoder = JSONDecoder()
        let settings = try decoder.decode(ClaudeSettings.self, from: data)

        #expect(settings.permissions?.count == 1)
        #expect(settings.permissions?["ReadOnly"]?.decision == "allow")
        #expect(settings.env == nil)
        #expect(settings.hooks == nil)
    }

    // MARK: - Parse stats cache

    @Test("Parse stats-cache.json v2 fixture — fields correct")
    func parseStatsCacheFixture() throws {
        let data = try loadFixture(named: "sample-stats-cache.json")
        let decoder = JSONDecoder()
        let statsCache = try decoder.decode(ClaudeStatsCache.self, from: data)

        #expect(statsCache.version == 2)
        #expect(statsCache.lastComputedDate == "2026-02-16")
        #expect(statsCache.totalSessions == 42)
        #expect(statsCache.totalMessages == 5000)
        #expect(statsCache.firstSessionDate == "2025-12-09T21:47:40.103Z")
        #expect(statsCache.totalSpeculationTimeSavedMs == 0)

        #expect(statsCache.dailyActivity?.count == 2)
        #expect(statsCache.dailyActivity?[0].date == "2026-02-15")
        #expect(statsCache.dailyActivity?[0].messageCount == 120)

        #expect(statsCache.modelUsage?["claude-opus-4-6"]?.inputTokens == 300000)
        #expect(statsCache.modelUsage?["claude-opus-4-6"]?.costUSD == 7.50)

        #expect(statsCache.longestSession?.sessionId == "sess-longest")
        #expect(statsCache.longestSession?.duration == 7200000)

        #expect(statsCache.hourCounts?["10"] == 25)
    }

    // MARK: - Parse history JSONL

    @Test("Parse history.jsonl fixture — multiple records parsed in order")
    func parseHistoryJSONL() throws {
        let data = try loadFixture(named: "sample-history.jsonl")
        let raw = String(data: data, encoding: .utf8)!

        let decoder = JSONDecoder()
        var entries: [ClaudeSessionHistoryEntry] = []

        for line in raw.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard let data = trimmed.data(using: .utf8) else { continue }
            let entry = try decoder.decode(ClaudeSessionHistoryEntry.self, from: data)
            entries.append(entry)
        }

        #expect(entries.count == 5)
        #expect(entries[0].sessionId == "sess-001")
        #expect(entries[0].type == "user")
        #expect(entries[0].content == "Hello, how can I help?")
        #expect(entries[1].model == "claude-opus-4-6")
        #expect(entries[1].inputTokens == 100)
        #expect(entries[1].outputTokens == 50)
        #expect(entries[3].sessionId == "sess-002")
        #expect(entries[4].model == "claude-sonnet-4-6")
    }

    // MARK: - Parse empty settings

    @Test("Parse empty settings JSON object")
    func parseEmptySettings() throws {
        let emptyJSON = "{}"
        let decoder = JSONDecoder()
        let data = emptyJSON.data(using: .utf8)!
        let settings = try decoder.decode(ClaudeSettings.self, from: data)

        #expect(settings.permissions == nil)
        #expect(settings.env == nil)
        #expect(settings.hooks == nil)
    }

    // MARK: - Stats cache with missing optional fields

    @Test("Parse stats-cache.json with missing optional fields")
    func parseStatsCachePartial() throws {
        let partialJSON = """
        {
            "version": 2,
            "totalSessions": 10
        }
        """
        let decoder = JSONDecoder()
        let data = partialJSON.data(using: .utf8)!
        let statsCache = try decoder.decode(ClaudeStatsCache.self, from: data)

        #expect(statsCache.version == 2)
        #expect(statsCache.totalSessions == 10)
        #expect(statsCache.totalMessages == nil)
        #expect(statsCache.dailyActivity == nil)
        #expect(statsCache.modelUsage == nil)
    }
}
