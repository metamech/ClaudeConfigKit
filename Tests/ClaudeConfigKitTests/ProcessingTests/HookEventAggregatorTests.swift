import Foundation
import Testing

@testable import ClaudeConfigKit

@Suite("HookEventAggregator")
struct HookEventAggregatorTests {

    @Test("groupBySession groups events correctly")
    func groupBySession() {
        let events = [
            HookEvent(sessionId: "a", eventType: .preToolUse),
            HookEvent(sessionId: "b", eventType: .sessionStart),
            HookEvent(sessionId: "a", eventType: .postToolUse),
        ]

        let grouped = HookEventAggregator.groupBySession(events)
        #expect(grouped.count == 2)
        #expect(grouped["a"]?.count == 2)
        #expect(grouped["b"]?.count == 1)
    }

    @Test("summarize computes correct counts")
    func summarize() {
        let events = [
            HookEvent(sessionId: "a", eventType: .preToolUse, toolName: "Bash"),
            HookEvent(sessionId: "a", eventType: .postToolUse, toolName: "Bash"),
            HookEvent(sessionId: "a", eventType: .notification),
        ]

        let summary = HookEventAggregator.summarize(sessionId: "a", events: events)

        #expect(summary.sessionId == "a")
        #expect(summary.eventCount == 3)
        #expect(summary.eventTypeCounts[.preToolUse] == 1)
        #expect(summary.eventTypeCounts[.postToolUse] == 1)
        #expect(summary.eventTypeCounts[.notification] == 1)
        #expect(summary.categoryCounts[.toolUse] == 2)
        #expect(summary.categoryCounts[.notification] == 1)
    }

    @Test("summarize tracks timestamps")
    func summarizeTimestamps() {
        let early = Date(timeIntervalSince1970: 1000)
        let late = Date(timeIntervalSince1970: 2000)
        let events = [
            HookEvent(sessionId: "a", eventType: .preToolUse, timestamp: early),
            HookEvent(sessionId: "a", eventType: .postToolUse, timestamp: late),
        ]

        let summary = HookEventAggregator.summarize(sessionId: "a", events: events)

        #expect(summary.firstEventAt == early)
        #expect(summary.lastEventAt == late)
        #expect(summary.duration == 1000)
    }

    @Test("summarizeAll produces per-session summaries")
    func summarizeAll() {
        let events = [
            HookEvent(sessionId: "a", eventType: .preToolUse),
            HookEvent(sessionId: "b", eventType: .sessionStart),
            HookEvent(sessionId: "a", eventType: .postToolUse),
        ]

        let summaries = HookEventAggregator.summarizeAll(events)
        #expect(summaries.count == 2)

        let summaryA = summaries.first { $0.sessionId == "a" }
        let summaryB = summaries.first { $0.sessionId == "b" }
        #expect(summaryA?.eventCount == 2)
        #expect(summaryB?.eventCount == 1)
    }

    @Test("Empty events produce empty results")
    func emptyEvents() {
        let summaries = HookEventAggregator.summarizeAll([])
        #expect(summaries.isEmpty)
    }
}
