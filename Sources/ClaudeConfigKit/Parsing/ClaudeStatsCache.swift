import Foundation

// MARK: - ClaudeStatsCache

/// Codable representation of `~/.claude/stats-cache.json` (v2 schema).
///
/// The file stores cumulative usage statistics that Claude Code uses for
/// its `/cost` command.  All fields are optional — the schema has changed
/// between Claude Code versions, so lenient decoding is essential.
public struct ClaudeStatsCache: Codable, Sendable {

    // MARK: - Top-level fields

    public var version: Int?
    public var lastComputedDate: String?
    public var totalSessions: Int?
    public var totalMessages: Int?
    public var firstSessionDate: String?
    public var totalSpeculationTimeSavedMs: Int?

    // MARK: - Daily activity

    public var dailyActivity: [DailyActivity]?

    // MARK: - Daily model tokens

    public var dailyModelTokens: [DailyModelTokens]?

    // MARK: - Per-model usage

    public var modelUsage: [String: ModelTokenUsage]?

    // MARK: - Longest session

    public var longestSession: LongestSession?

    // MARK: - Hour counts

    public var hourCounts: [String: Int]?

    public init(
        version: Int? = nil,
        lastComputedDate: String? = nil,
        totalSessions: Int? = nil,
        totalMessages: Int? = nil,
        firstSessionDate: String? = nil,
        totalSpeculationTimeSavedMs: Int? = nil,
        dailyActivity: [DailyActivity]? = nil,
        dailyModelTokens: [DailyModelTokens]? = nil,
        modelUsage: [String: ModelTokenUsage]? = nil,
        longestSession: LongestSession? = nil,
        hourCounts: [String: Int]? = nil
    ) {
        self.version = version
        self.lastComputedDate = lastComputedDate
        self.totalSessions = totalSessions
        self.totalMessages = totalMessages
        self.firstSessionDate = firstSessionDate
        self.totalSpeculationTimeSavedMs = totalSpeculationTimeSavedMs
        self.dailyActivity = dailyActivity
        self.dailyModelTokens = dailyModelTokens
        self.modelUsage = modelUsage
        self.longestSession = longestSession
        self.hourCounts = hourCounts
    }
}

// MARK: - DailyActivity

public struct DailyActivity: Codable, Sendable {
    public var date: String?
    public var messageCount: Int?
    public var sessionCount: Int?
    public var toolCallCount: Int?

    public init(date: String? = nil, messageCount: Int? = nil, sessionCount: Int? = nil, toolCallCount: Int? = nil) {
        self.date = date
        self.messageCount = messageCount
        self.sessionCount = sessionCount
        self.toolCallCount = toolCallCount
    }
}

// MARK: - DailyModelTokens

public struct DailyModelTokens: Codable, Sendable {
    public var date: String?
    public var tokensByModel: [String: Int]?

    public init(date: String? = nil, tokensByModel: [String: Int]? = nil) {
        self.date = date
        self.tokensByModel = tokensByModel
    }
}

// MARK: - ModelTokenUsage

public struct ModelTokenUsage: Codable, Sendable {
    public var inputTokens: Int?
    public var outputTokens: Int?
    public var cacheReadInputTokens: Int?
    public var cacheCreationInputTokens: Int?
    public var webSearchRequests: Int?
    public var costUSD: Double?
    public var contextWindow: Int?
    public var maxOutputTokens: Int?

    public init(
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        cacheReadInputTokens: Int? = nil,
        cacheCreationInputTokens: Int? = nil,
        webSearchRequests: Int? = nil,
        costUSD: Double? = nil,
        contextWindow: Int? = nil,
        maxOutputTokens: Int? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.webSearchRequests = webSearchRequests
        self.costUSD = costUSD
        self.contextWindow = contextWindow
        self.maxOutputTokens = maxOutputTokens
    }
}

// MARK: - LongestSession

public struct LongestSession: Codable, Sendable {
    public var sessionId: String?
    public var duration: Int?
    public var messageCount: Int?
    public var timestamp: String?

    public init(sessionId: String? = nil, duration: Int? = nil, messageCount: Int? = nil, timestamp: String? = nil) {
        self.sessionId = sessionId
        self.duration = duration
        self.messageCount = messageCount
        self.timestamp = timestamp
    }
}
