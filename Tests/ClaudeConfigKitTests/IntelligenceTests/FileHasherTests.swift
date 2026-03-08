import Foundation
import Testing

@testable import ClaudeConfigKit

@Suite("FileHasher Tests")
struct FileHasherTests {

    @Test("Deterministic hash for same data")
    func deterministicHash() {
        let data = Data("hello world".utf8)
        let hash1 = FileHasher.hash(data: data)
        let hash2 = FileHasher.hash(data: data)
        #expect(hash1 == hash2)
        #expect(hash1.count == 64) // SHA-256 hex = 64 chars
    }

    @Test("Different data produces different hashes")
    func differentDataDifferentHash() {
        let hash1 = FileHasher.hash(data: Data("hello".utf8))
        let hash2 = FileHasher.hash(data: Data("world".utf8))
        #expect(hash1 != hash2)
    }

    @Test("Empty data produces valid hash")
    func emptyDataHash() {
        let hash = FileHasher.hash(data: Data())
        #expect(hash.count == 64)
        // SHA-256 of empty data is well-known
        #expect(hash == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    @Test("Hash file from disk")
    func hashFileFromDisk() throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("cck-hash-test-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let content = "test file content"
        try content.write(to: tempFile, atomically: true, encoding: .utf8)

        let fileHash = try FileHasher.hash(fileAt: tempFile)
        let dataHash = FileHasher.hash(data: Data(content.utf8))
        #expect(fileHash == dataHash)
    }

    @Test("Hash nonexistent file throws")
    func hashNonexistentFileThrows() {
        let url = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString)")
        #expect(throws: (any Error).self) {
            _ = try FileHasher.hash(fileAt: url)
        }
    }

    @Test("Async hash file from disk")
    func asyncHashFileFromDisk() async throws {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("cck-async-hash-test-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let content = "async test file content"
        try content.write(to: tempFile, atomically: true, encoding: .utf8)

        let fileHash: String = try await FileHasher.hash(fileAt: tempFile)
        let dataHash = FileHasher.hash(data: Data(content.utf8))
        #expect(fileHash == dataHash)
    }

    @Test("Async hash nonexistent file throws")
    func asyncHashNonexistentFileThrows() async {
        let url = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString)")
        do {
            let _: String = try await FileHasher.hash(fileAt: url)
            Issue.record("Expected error for nonexistent file")
        } catch {
            // Expected
        }
    }
}
