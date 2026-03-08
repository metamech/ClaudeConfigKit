import Foundation
import Testing

@testable import ClaudeConfigKit

@Suite("Batch Baseline Tests")
struct BatchBaselineTests {

    func createTempFile(content: String, extension ext: String = "json") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cck-batch-\(UUID().uuidString).\(ext)")
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Batch capture

    @Test("Batch capture baselines for multiple files")
    func batchCaptureBaselines() async throws {
        let url1 = try createTempFile(content: "{\"key\": \"value1\"}")
        let url2 = try createTempFile(content: "{\"key\": \"value2\"}")
        let url3 = try createTempFile(content: "# Title\nContent", extension: "md")
        defer {
            try? FileManager.default.removeItem(at: url1)
            try? FileManager.default.removeItem(at: url2)
            try? FileManager.default.removeItem(at: url3)
        }

        let engine = BaselineEngine()
        let baselines = try await engine.captureBaselines(for: [url1, url2, url3])

        #expect(baselines.count == 3)
        let paths = Set(baselines.map(\.filePath))
        #expect(paths.contains(url1.path))
        #expect(paths.contains(url2.path))
        #expect(paths.contains(url3.path))
    }

    @Test("Batch capture empty list returns empty")
    func batchCaptureEmpty() async throws {
        let engine = BaselineEngine()
        let baselines = try await engine.captureBaselines(for: [])
        #expect(baselines.isEmpty)
    }

    // MARK: - Batch change detection

    @Test("Batch detect changes with deduplication")
    func batchDetectChangesDeduplicates() async throws {
        let url = try createTempFile(content: "{\"key\": \"value1\"}")
        defer { try? FileManager.default.removeItem(at: url) }

        let engine = BaselineEngine()
        let baseline = try await engine.captureBaseline(for: url)

        // Modify the file
        try "{\"key\": \"value2\"}".write(to: url, atomically: true, encoding: .utf8)

        // Create duplicate events for same path
        let events = [
            FileChangeEvent(path: url.path, flags: .modified),
            FileChangeEvent(path: url.path, flags: .modified),
        ]

        let baselines = [url.path: baseline]
        let changes = try await engine.detectChanges(for: events, against: baselines)

        // Should only produce one change record despite two events
        #expect(changes.count == 1)
        #expect(changes[0].changeType == .dataChange)
    }

    @Test("Batch detect changes for multiple files")
    func batchDetectChangesMultipleFiles() async throws {
        let url1 = try createTempFile(content: "{\"key\": \"value1\"}")
        let url2 = try createTempFile(content: "{\"key\": \"value2\"}")
        defer {
            try? FileManager.default.removeItem(at: url1)
            try? FileManager.default.removeItem(at: url2)
        }

        let engine = BaselineEngine()
        let baseline1 = try await engine.captureBaseline(for: url1)
        let baseline2 = try await engine.captureBaseline(for: url2)

        // Modify both files
        try "{\"key\": \"changed1\"}".write(to: url1, atomically: true, encoding: .utf8)
        try "{\"key\": \"changed2\"}".write(to: url2, atomically: true, encoding: .utf8)

        let events = [
            FileChangeEvent(path: url1.path, flags: .modified),
            FileChangeEvent(path: url2.path, flags: .modified),
        ]

        let baselines = [url1.path: baseline1, url2.path: baseline2]
        let changes = try await engine.detectChanges(for: events, against: baselines)

        #expect(changes.count == 2)
    }

    // MARK: - Update baseline

    @Test("Update baseline returns fresh snapshot")
    func updateBaseline() async throws {
        let url = try createTempFile(content: "{\"key\": \"original\"}")
        defer { try? FileManager.default.removeItem(at: url) }

        let engine = BaselineEngine()
        let original = try await engine.captureBaseline(for: url)

        try "{\"key\": \"updated\"}".write(to: url, atomically: true, encoding: .utf8)

        let updated = try await engine.updateBaseline(original, from: url)

        #expect(updated.filePath == original.filePath)
        #expect(updated.contentHash != original.contentHash)
        #expect(updated.capturedAt >= original.capturedAt)
    }
}
