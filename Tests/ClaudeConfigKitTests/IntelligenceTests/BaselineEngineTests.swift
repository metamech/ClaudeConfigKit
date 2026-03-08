import Foundation
import Testing

@testable import ClaudeConfigKit

@Suite("BaselineEngine Tests")
struct BaselineEngineTests {

    func createTempFile(content: String, extension ext: String = "json") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cck-baseline-\(UUID().uuidString).\(ext)")
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Capture baseline

    @Test("Capture baseline for JSON file")
    func captureJSONBaseline() async throws {
        let content = "{\"key\": \"value\", \"count\": 42}"
        let url = try createTempFile(content: content)
        defer { try? FileManager.default.removeItem(at: url) }

        let engine = BaselineEngine()
        let baseline = try await engine.captureBaseline(for: url)

        #expect(baseline.filePath == url.path)
        #expect(baseline.contentHash.count == 64)
        #expect(baseline.schema.keyPaths["key"] == .string)
        #expect(baseline.schema.keyPaths["count"] == .number)
        #expect(baseline.schema.fingerprint.count == 64)
    }

    @Test("Capture baseline for Markdown file")
    func captureMarkdownBaseline() async throws {
        let content = "# Title\n## Section\nContent here"
        let url = try createTempFile(content: content, extension: "md")
        defer { try? FileManager.default.removeItem(at: url) }

        let engine = BaselineEngine()
        let baseline = try await engine.captureBaseline(for: url)

        #expect(baseline.schema.headings.count == 2)
        #expect(baseline.schema.headings[0] == Heading(level: 1, text: "Title"))
        #expect(baseline.schema.headings[1] == Heading(level: 2, text: "Section"))
    }

    // MARK: - Detect changes

    @Test("No change detected when file unchanged")
    func noChangeDetected() async throws {
        let content = "{\"key\": \"value\"}"
        let url = try createTempFile(content: content)
        defer { try? FileManager.default.removeItem(at: url) }

        let engine = BaselineEngine()
        let baseline = try await engine.captureBaseline(for: url)
        let change = try await engine.detectChanges(for: url, against: baseline)

        #expect(change == nil)
    }

    @Test("Data change detected when content changes but schema stays same")
    func dataChangeDetected() async throws {
        let url = try createTempFile(content: "{\"key\": \"value1\"}")
        defer { try? FileManager.default.removeItem(at: url) }

        let engine = BaselineEngine()
        let baseline = try await engine.captureBaseline(for: url)

        // Overwrite with different value but same schema
        try "{\"key\": \"value2\"}".write(to: url, atomically: true, encoding: .utf8)

        let change = try await engine.detectChanges(for: url, against: baseline)
        #expect(change != nil)
        #expect(change?.changeType == .dataChange)
        #expect(change?.diffData != nil)
        let diffString = String(data: change!.diffData!, encoding: .utf8)
        #expect(diffString?.contains("value2") == true)
    }

    @Test("Schema change detected when structure changes")
    func schemaChangeDetected() async throws {
        let url = try createTempFile(content: "{\"key\": \"value\"}")
        defer { try? FileManager.default.removeItem(at: url) }

        let engine = BaselineEngine()
        let baseline = try await engine.captureBaseline(for: url)

        // Overwrite with new key
        try "{\"key\": \"value\", \"newKey\": 42}".write(to: url, atomically: true, encoding: .utf8)

        let change = try await engine.detectChanges(for: url, against: baseline)
        #expect(change != nil)
        #expect(change?.changeType == .schemaChange)
        #expect(change?.previousFingerprint != nil)
        #expect(change?.currentFingerprint != nil)
        #expect(change?.previousFingerprint != change?.currentFingerprint)
    }

    @Test("File removed detected")
    func fileRemovedDetected() async throws {
        let url = try createTempFile(content: "{\"key\": \"value\"}")

        let engine = BaselineEngine()
        let baseline = try await engine.captureBaseline(for: url)

        try FileManager.default.removeItem(at: url)

        let change = try await engine.detectChanges(for: url, against: baseline)
        #expect(change != nil)
        #expect(change?.changeType == .fileRemoved)
        #expect(change?.diffData == nil)
    }
}
