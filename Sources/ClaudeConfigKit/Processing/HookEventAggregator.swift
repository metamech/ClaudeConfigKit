import Foundation

// MARK: - SessionEventSummary

/// Stateless summary of events for a single session.
public struct SessionEventSummary: Sendable {
    /// The session ID.
    public let sessionId: String

    /// Total number of events processed.
    public let eventCount: Int

    /// Breakdown by event type.
    public let eventTypeCounts: [HookEventType: Int]

    /// Breakdown by category.
    public let categoryCounts: [HookEventCategory: Int]

    /// Earliest event timestamp.
    public let firstEventAt: Date?

    /// Latest event timestamp.
    public let lastEventAt: Date?

    /// Duration from first to last event.
    public var duration: TimeInterval? {
        guard let first = firstEventAt, let last = lastEventAt else { return nil }
        return last.timeIntervalSince(first)
    }

    public init(
        sessionId: String,
        eventCount: Int,
        eventTypeCounts: [HookEventType: Int],
        categoryCounts: [HookEventCategory: Int],
        firstEventAt: Date?,
        lastEventAt: Date?
    ) {
        self.sessionId = sessionId
        self.eventCount = eventCount
        self.eventTypeCounts = eventTypeCounts
        self.categoryCounts = categoryCounts
        self.firstEventAt = firstEventAt
        self.lastEventAt = lastEventAt
    }
}

// MARK: - HookEventAggregator

/// Stateless utility for grouping and summarizing hook events.
public enum HookEventAggregator {

    /// Group events by session ID.
    public static func groupBySession(
        _ events: [HookEvent]
    ) -> [String: [HookEvent]] {
        Dictionary(grouping: events, by: \.sessionId)
    }

    /// Compute a summary for a list of events belonging to a single session.
    public static func summarize(
        sessionId: String,
        events: [HookEvent]
    ) -> SessionEventSummary {
        var typeCounts: [HookEventType: Int] = [:]
        var categoryCounts: [HookEventCategory: Int] = [:]
        var firstAt: Date?
        var lastAt: Date?

        for event in events {
            typeCounts[event.eventType, default: 0] += 1
            let category = HookEventClassifier.classify(event)
            categoryCounts[category, default: 0] += 1

            if firstAt == nil || event.timestamp < firstAt! {
                firstAt = event.timestamp
            }
            if lastAt == nil || event.timestamp > lastAt! {
                lastAt = event.timestamp
            }
        }

        return SessionEventSummary(
            sessionId: sessionId,
            eventCount: events.count,
            eventTypeCounts: typeCounts,
            categoryCounts: categoryCounts,
            firstEventAt: firstAt,
            lastEventAt: lastAt
        )
    }

    /// Summarize all events, grouped by session.
    public static func summarizeAll(
        _ events: [HookEvent]
    ) -> [SessionEventSummary] {
        let grouped = groupBySession(events)
        return grouped.map { (sessionId, sessionEvents) in
            summarize(sessionId: sessionId, events: sessionEvents)
        }
    }
}
