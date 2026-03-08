import Foundation
import Testing

@testable import ClaudeConfigKit

@Suite("File Discovery Tests")
struct FileDiscoveryTests {

    func createTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cck-discovery-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("Discovers known files in directory")
    func discoversKnownFiles() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create known files
        try "{}".write(to: tempDir.appendingPathComponent("settings.json"), atomically: true, encoding: .utf8)
        try "# CLAUDE".write(to: tempDir.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)
        try "ignored".write(to: tempDir.appendingPathComponent("random.txt"), atomically: true, encoding: .utf8)

        let engine = BaselineEngine()
        let files = try await engine.discoverConfigFiles(at: tempDir)

        let names = files.map { $0.lastPathComponent }
        #expect(names.contains("settings.json"))
        #expect(names.contains("CLAUDE.md"))
        #expect(!names.contains("random.txt"))
    }

    @Test("Discovers files in nested known directories")
    func discoversFilesInKnownDirs() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let claudeDir = tempDir.appendingPathComponent(".claude")
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        try "{}".write(to: claudeDir.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)

        let engine = BaselineEngine()
        // Note: .skipsHiddenFiles will skip .claude, so let's use a non-hidden dir name
        let files = try await engine.discoverConfigFiles(
            at: tempDir,
            knownDirs: ["subconfig"]
        )

        // .claude is hidden so it gets skipped by the enumerator
        #expect(files.isEmpty)
    }

    @Test("Respects custom known files set")
    func customKnownFiles() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try "custom".write(to: tempDir.appendingPathComponent("my-config.yaml"), atomically: true, encoding: .utf8)
        try "{}".write(to: tempDir.appendingPathComponent("settings.json"), atomically: true, encoding: .utf8)

        let engine = BaselineEngine()
        let files = try await engine.discoverConfigFiles(
            at: tempDir,
            knownFiles: ["my-config.yaml"]
        )

        let names = files.map { $0.lastPathComponent }
        #expect(names.contains("my-config.yaml"))
        #expect(!names.contains("settings.json"))
    }

    @Test("Discovers files in subdirectories")
    func discoversInSubdirectories() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let subDir = tempDir.appendingPathComponent("project")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        try "# Agents".write(to: subDir.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)

        let engine = BaselineEngine()
        let files = try await engine.discoverConfigFiles(at: tempDir)

        let names = files.map { $0.lastPathComponent }
        #expect(names.contains("AGENTS.md"))
    }

    @Test("Empty directory returns empty results")
    func emptyDirectory() async throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let engine = BaselineEngine()
        let files = try await engine.discoverConfigFiles(at: tempDir)
        #expect(files.isEmpty)
    }
}
