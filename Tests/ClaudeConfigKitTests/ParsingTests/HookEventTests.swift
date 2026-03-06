import Foundation
import Testing

@testable import ClaudeConfigKit

// MARK: - Hook Event Tests

@Suite("HookEvent Codable Tests")
struct HookEventTests {

    // MARK: - Decode HookEventType

    @Test("Decode PreToolUse event type")
    func decodePreToolUseEventType() throws {
        let json = """
        {
            "session_id": "abc-123",
            "hook_event_name": "PreToolUse"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        #expect(event.eventType == .preToolUse)
    }

    @Test("Decode PostToolUse event type")
    func decodePostToolUseEventType() throws {
        let json = """
        {
            "session_id": "abc-123",
            "hook_event_name": "PostToolUse"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        #expect(event.eventType == .postToolUse)
    }

    @Test("Decode Notification event type")
    func decodeNotificationEventType() throws {
        let json = """
        {
            "session_id": "abc-123",
            "hook_event_name": "Notification"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        #expect(event.eventType == .notification)
    }

    @Test("Decode Stop event type")
    func decodeStopEventType() throws {
        let json = """
        {
            "session_id": "def-456",
            "hook_event_name": "Stop"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        #expect(event.eventType == .stop)
    }

    @Test("Decode SessionStart event type")
    func decodeSessionStartEventType() throws {
        let json = """
        {
            "session_id": "abc-123",
            "hook_event_name": "SessionStart"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        #expect(event.eventType == .sessionStart)
    }

    @Test("Decode SessionEnd event type")
    func decodeSessionEndEventType() throws {
        let json = """
        {
            "session_id": "abc-123",
            "hook_event_name": "SessionEnd"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        #expect(event.eventType == .sessionEnd)
    }

    // MARK: - Decode PreToolUse with Full Fields

    @Test("Decode PreToolUse event with full fields")
    func decodePreToolUseEventFull() throws {
        let json = """
        {
            "session_id": "abc-123",
            "hook_event_name": "PreToolUse",
            "tool_name": "Bash",
            "tool_input": {"command": "ls -la"},
            "cwd": "/Users/test/project"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)

        #expect(event.sessionId == "abc-123")
        #expect(event.eventType == .preToolUse)
        #expect(event.toolName == "Bash")
        #expect(event.workingDirectory == "/Users/test/project")
        #expect(event.toolInput != nil)
    }

    // MARK: - Decode with Optional Fields

    @Test("Decode event with minimal fields")
    func decodeMinimalEvent() throws {
        let json = """
        {
            "session_id": "s-001",
            "hook_event_name": "Stop"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)

        #expect(event.sessionId == "s-001")
        #expect(event.eventType == .stop)
        #expect(event.toolName == nil)
        #expect(event.toolInput == nil)
        #expect(event.workingDirectory == nil)
        #expect(event.rawPayload == nil)
    }

    // MARK: - Decode AnyCodableValue in tool_input

    @Test("Decode tool_input with string value")
    func decodeToolInputString() throws {
        let json = """
        {
            "session_id": "s1",
            "hook_event_name": "PreToolUse",
            "tool_input": {
                "command": "echo hello"
            }
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        if case .string(let cmd) = event.toolInput?["command"] {
            #expect(cmd == "echo hello")
        } else {
            Issue.record("Expected string for command")
        }
    }

    @Test("Decode tool_input with integer value")
    func decodeToolInputInteger() throws {
        let json = """
        {
            "session_id": "s1",
            "hook_event_name": "PreToolUse",
            "tool_input": {
                "timeout": 5000
            }
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        if case .int(let timeout) = event.toolInput?["timeout"] {
            #expect(timeout == 5000)
        } else {
            Issue.record("Expected int for timeout")
        }
    }

    @Test("Decode tool_input with boolean value")
    func decodeToolInputBoolean() throws {
        let json = """
        {
            "session_id": "s1",
            "hook_event_name": "PreToolUse",
            "tool_input": {
                "verbose": true
            }
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        if case .bool(let verbose) = event.toolInput?["verbose"] {
            #expect(verbose == true)
        } else {
            Issue.record("Expected bool for verbose")
        }
    }

    @Test("Decode tool_input with double value")
    func decodeToolInputDouble() throws {
        let json = """
        {
            "session_id": "s1",
            "hook_event_name": "PreToolUse",
            "tool_input": {
                "factor": 3.14
            }
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        if case .double(let factor) = event.toolInput?["factor"] {
            #expect(factor == 3.14)
        } else {
            Issue.record("Expected double for factor")
        }
    }

    @Test("Decode tool_input with null value")
    func decodeToolInputNull() throws {
        let json = """
        {
            "session_id": "s1",
            "hook_event_name": "PreToolUse",
            "tool_input": {
                "optional": null
            }
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        if case .null = event.toolInput?["optional"] {
            // OK
        } else {
            Issue.record("Expected null for optional")
        }
    }

    @Test("Decode tool_input with mixed types")
    func decodeToolInputMixed() throws {
        let json = """
        {
            "session_id": "s1",
            "hook_event_name": "PreToolUse",
            "tool_input": {
                "command": "echo hello",
                "timeout": 5000,
                "verbose": true,
                "factor": 2.5,
                "optional": null
            }
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        #expect(event.toolInput?.count == 5)
    }

    // MARK: - Round-trip Encode/Decode

    @Test("Encode and decode event round-trip")
    func encodeDecodeRoundTrip() throws {
        let event = HookEvent(
            sessionId: "rt-123",
            eventType: .notification,
            workingDirectory: "/tmp"
        )

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(HookEvent.self, from: data)

        #expect(decoded.sessionId == event.sessionId)
        #expect(decoded.eventType == event.eventType)
        #expect(decoded.workingDirectory == event.workingDirectory)
        // timestamp is set at decode time, not round-tripped
    }

    @Test("Encode and decode event with tool_input round-trip")
    func encodeDecodeWithToolInputRoundTrip() throws {
        let toolInput: [String: AnyCodableValue] = [
            "command": .string("ls -la"),
            "timeout": .int(30),
            "verbose": .bool(true)
        ]

        let event = HookEvent(
            sessionId: "rt-124",
            eventType: .preToolUse,
            toolName: "Bash",
            toolInput: toolInput,
            workingDirectory: "/home"
        )

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(HookEvent.self, from: data)

        #expect(decoded.sessionId == event.sessionId)
        #expect(decoded.eventType == event.eventType)
        #expect(decoded.toolName == event.toolName)
        #expect(decoded.toolInput?.count == toolInput.count)
    }

    // MARK: - Error Cases

    @Test("Decode unknown event type throws")
    func decodeUnknownEventTypeThrows() throws {
        let json = """
        {
            "session_id": "s",
            "hook_event_name": "FutureEvent"
        }
        """.data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(HookEvent.self, from: json)
        }
    }

    @Test("Decode missing session_id throws")
    func decodeMissingSessionIdThrows() throws {
        let json = """
        {
            "hook_event_name": "Stop"
        }
        """.data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(HookEvent.self, from: json)
        }
    }

    @Test("Decode missing hook_event_name throws")
    func decodeMissingEventTypeThrows() throws {
        let json = """
        {
            "session_id": "s"
        }
        """.data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(HookEvent.self, from: json)
        }
    }

    // MARK: - CodingKeys

    @Test("Decode with correct JSON keys from Claude Code payload")
    func decodeCorrectJSONKeys() throws {
        let json = """
        {
            "session_id": "s-001",
            "hook_event_name": "PreToolUse",
            "tool_name": "Read",
            "tool_input": {"file": "test.txt"},
            "cwd": "/tmp"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)

        #expect(event.sessionId == "s-001")
        #expect(event.toolName == "Read")
        #expect(event.workingDirectory == "/tmp")
    }

    // MARK: - Sendable Conformance

    @Test("HookEvent is Sendable")
    func hookEventIsSendable() throws {
        let json = """
        {
            "session_id": "s-001",
            "hook_event_name": "Stop"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)
        nonisolated(unsafe) let _ = event
    }
}

// MARK: - HookEventType Tests

@Suite("HookEventType Codable Tests")
struct HookEventTypeTests {

    @Test("Encode and decode all event types")
    func encodeDecodeAllEventTypes() throws {
        let types: [HookEventType] = [
            .preToolUse, .postToolUse, .postToolUseFailure, .notification,
            .stop, .sessionStart, .sessionEnd, .userPromptSubmit,
            .permissionRequest, .subagentStart, .subagentStop, .preCompact,
            .configChange, .taskCompleted, .teammateIdle,
            .worktreeCreate, .worktreeRemove,
        ]

        for type in types {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(HookEventType.self, from: data)
            #expect(decoded == type)
        }
    }

    @Test("Event type raw values match expected strings")
    func eventTypeRawValues() {
        #expect(HookEventType.preToolUse.rawValue == "PreToolUse")
        #expect(HookEventType.postToolUse.rawValue == "PostToolUse")
        #expect(HookEventType.postToolUseFailure.rawValue == "PostToolUseFailure")
        #expect(HookEventType.notification.rawValue == "Notification")
        #expect(HookEventType.stop.rawValue == "Stop")
        #expect(HookEventType.sessionStart.rawValue == "SessionStart")
        #expect(HookEventType.sessionEnd.rawValue == "SessionEnd")
        #expect(HookEventType.userPromptSubmit.rawValue == "UserPromptSubmit")
        #expect(HookEventType.permissionRequest.rawValue == "PermissionRequest")
        #expect(HookEventType.subagentStart.rawValue == "SubagentStart")
        #expect(HookEventType.subagentStop.rawValue == "SubagentStop")
        #expect(HookEventType.preCompact.rawValue == "PreCompact")
        #expect(HookEventType.configChange.rawValue == "ConfigChange")
        #expect(HookEventType.taskCompleted.rawValue == "TaskCompleted")
        #expect(HookEventType.teammateIdle.rawValue == "TeammateIdle")
        #expect(HookEventType.worktreeCreate.rawValue == "WorktreeCreate")
        #expect(HookEventType.worktreeRemove.rawValue == "WorktreeRemove")
    }
}

// MARK: - AnyCodableValue Tests

@Suite("AnyCodableValue Codable Tests")
struct AnyCodableValueTests {

    @Test("Encode and decode string value")
    func encodeDecodeString() throws {
        let value = AnyCodableValue.string("hello")
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: data)
        if case .string(let s) = decoded {
            #expect(s == "hello")
        } else {
            Issue.record("Expected string value")
        }
    }

    @Test("Encode and decode int value")
    func encodeDecodeInt() throws {
        let value = AnyCodableValue.int(42)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: data)
        if case .int(let i) = decoded {
            #expect(i == 42)
        } else {
            Issue.record("Expected int value")
        }
    }

    @Test("Encode and decode double value")
    func encodeDecodeDouble() throws {
        let value = AnyCodableValue.double(3.14)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: data)
        if case .double(let d) = decoded {
            #expect(d == 3.14)
        } else {
            Issue.record("Expected double value")
        }
    }

    @Test("Encode and decode bool value")
    func encodeDecodeBool() throws {
        let value = AnyCodableValue.bool(true)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: data)
        if case .bool(let b) = decoded {
            #expect(b == true)
        } else {
            Issue.record("Expected bool value")
        }
    }

    @Test("Encode and decode null value")
    func encodeDecodeNull() throws {
        let value = AnyCodableValue.null
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: data)
        if case .null = decoded {
            // OK
        } else {
            Issue.record("Expected null value")
        }
    }

    @Test("Decode bool before int (bool true vs int 1)")
    func decodeBoolBeforeInt() throws {
        let json = "true".data(using: .utf8)!
        let value = try JSONDecoder().decode(AnyCodableValue.self, from: json)
        if case .bool(let b) = value {
            #expect(b == true)
        } else {
            Issue.record("Expected bool, not int")
        }
    }

    @Test("Decode bool false")
    func decodeBoolFalse() throws {
        let json = "false".data(using: .utf8)!
        let value = try JSONDecoder().decode(AnyCodableValue.self, from: json)
        if case .bool(let b) = value {
            #expect(b == false)
        } else {
            Issue.record("Expected bool false")
        }
    }
}
