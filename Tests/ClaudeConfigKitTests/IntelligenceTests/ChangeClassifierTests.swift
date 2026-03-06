import Foundation
import Testing

@testable import ClaudeConfigKit

@Suite("ChangeClassifier Tests")
struct ChangeClassifierTests {

    @Test("File added — no previous baseline")
    func fileAdded() {
        let data = Data("{\"key\": \"value\"}".utf8)
        let url = URL(fileURLWithPath: "/tmp/test.json")

        let changeType = ChangeClassifier.classify(
            previousBaseline: nil,
            currentData: data,
            currentURL: url
        )
        #expect(changeType == .fileAdded)
    }

    @Test("File removed — baseline exists but no current data")
    func fileRemoved() {
        let baseline = ConfigBaseline(
            filePath: "/tmp/test.json",
            contentHash: "abc123",
            schema: SchemaStructure(fingerprint: "def456")
        )

        let changeType = ChangeClassifier.classify(
            previousBaseline: baseline,
            currentData: nil,
            currentURL: URL(fileURLWithPath: "/tmp/test.json")
        )
        #expect(changeType == .fileRemoved)
    }

    @Test("Data change — same schema, different content")
    func dataChange() throws {
        let originalJSON = "{\"key\": \"value1\"}"
        let changedJSON = "{\"key\": \"value2\"}"
        let url = URL(fileURLWithPath: "/tmp/test.json")

        let originalData = Data(originalJSON.utf8)
        let originalSchema = try SchemaExtractor.extractJSON(from: originalData)

        let baseline = ConfigBaseline(
            filePath: url.path,
            contentHash: FileHasher.hash(data: originalData),
            schema: originalSchema
        )

        let changeType = ChangeClassifier.classify(
            previousBaseline: baseline,
            currentData: Data(changedJSON.utf8),
            currentURL: url
        )
        #expect(changeType == .dataChange)
    }

    @Test("Schema change — different structure")
    func schemaChange() throws {
        let originalJSON = "{\"key\": \"value\"}"
        let changedJSON = "{\"key\": \"value\", \"newKey\": 42}"
        let url = URL(fileURLWithPath: "/tmp/test.json")

        let originalData = Data(originalJSON.utf8)
        let originalSchema = try SchemaExtractor.extractJSON(from: originalData)

        let baseline = ConfigBaseline(
            filePath: url.path,
            contentHash: FileHasher.hash(data: originalData),
            schema: originalSchema
        )

        let changeType = ChangeClassifier.classify(
            previousBaseline: baseline,
            currentData: Data(changedJSON.utf8),
            currentURL: url
        )
        #expect(changeType == .schemaChange)
    }
}
