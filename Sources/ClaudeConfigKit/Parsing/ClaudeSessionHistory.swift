import Foundation

// MARK: - ClaudeSessionHistoryEntry

/// One line from a `.jsonl` history file found at
/// `~/.claude/projects/<encoded-path>/history.jsonl`.
///
/// Each line in the file is a self-contained JSON object.  The schema varies by
/// line type, so every field is optional.  Unknown keys are silently discarded.
///
/// Dates arrive as Unix epoch milliseconds (an integer); the custom decoder
/// converts them to `Date`.
public struct ClaudeSessionHistoryEntry: Codable, Sendable {

    // MARK: - Common fields

    public var sessionId: String?
    public var timestamp: Date?
    public var type: String?

    // MARK: - Message content

    public var content: String?
    public var model: String?

    // MARK: - Token usage

    public var inputTokens: Int?
    public var outputTokens: Int?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case sessionId    = "session_id"
        case timestamp
        case type
        case content
        case model
        case inputTokens  = "input_tokens"
        case outputTokens = "output_tokens"
    }

    // MARK: - Custom Decoding

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        sessionId    = try container.decodeIfPresent(String.self, forKey: .sessionId)
        type         = try container.decodeIfPresent(String.self, forKey: .type)
        content      = try container.decodeIfPresent(String.self, forKey: .content)
        model        = try container.decodeIfPresent(String.self, forKey: .model)
        inputTokens  = try container.decodeIfPresent(Int.self, forKey: .inputTokens)
        outputTokens = try container.decodeIfPresent(Int.self, forKey: .outputTokens)

        if let epochMs = try container.decodeIfPresent(Double.self, forKey: .timestamp) {
            timestamp = Date(timeIntervalSince1970: epochMs / 1_000)
        } else {
            timestamp = nil
        }
    }

    public init(
        sessionId: String? = nil,
        timestamp: Date? = nil,
        type: String? = nil,
        content: String? = nil,
        model: String? = nil,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil
    ) {
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.type = type
        self.content = content
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}
