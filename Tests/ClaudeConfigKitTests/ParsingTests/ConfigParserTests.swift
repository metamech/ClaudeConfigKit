import Foundation
import Testing

@testable import ClaudeConfigKit

// MARK: - Mock FileProvider

struct MockFileProvider: FileProvider {
    var files: [String: Data] = [:]
    var fileSizes: [String: UInt64] = [:]

    func read(at url: URL) async throws -> Data {
        guard let data = files[url.path] else {
            throw ConfigParserError.fileNotReadable(url)
        }
        return data
    }

    func exists(at url: URL) async -> Bool {
        files[url.path] != nil
    }

    func size(of url: URL) async throws -> UInt64 {
        fileSizes[url.path] ?? UInt64(files[url.path]?.count ?? 0)
    }
}

@Suite("ConfigParser Tests")
struct ConfigParserTests {

    // MARK: - File type detection

    @Test("Detect JSON file type")
    func detectJSON() {
        let url = URL(fileURLWithPath: "/tmp/config.json")
        #expect(ConfigParser.detectFileType(for: url) == .json)
    }

    @Test("Detect JSONL file type")
    func detectJSONL() {
        let url = URL(fileURLWithPath: "/tmp/history.jsonl")
        #expect(ConfigParser.detectFileType(for: url) == .jsonl)
    }

    @Test("Detect Markdown file type")
    func detectMarkdown() {
        let md = URL(fileURLWithPath: "/tmp/CLAUDE.md")
        let markdown = URL(fileURLWithPath: "/tmp/README.markdown")
        #expect(ConfigParser.detectFileType(for: md) == .markdown)
        #expect(ConfigParser.detectFileType(for: markdown) == .markdown)
    }

    @Test("Detect YAML file type")
    func detectYAML() {
        let yaml = URL(fileURLWithPath: "/tmp/config.yaml")
        let yml = URL(fileURLWithPath: "/tmp/config.yml")
        #expect(ConfigParser.detectFileType(for: yaml) == .yaml)
        #expect(ConfigParser.detectFileType(for: yml) == .yaml)
    }

    @Test("Detect unknown file type")
    func detectUnknown() {
        let url = URL(fileURLWithPath: "/tmp/config.toml")
        #expect(ConfigParser.detectFileType(for: url) == .unknown)
    }

    // MARK: - Parsing with mock provider

    @Test("Parse JSON file via mock provider")
    func parseJSON() async throws {
        let url = URL(fileURLWithPath: "/tmp/settings.json")
        let json = "{\"key\": \"value\", \"count\": 42}"
        var provider = MockFileProvider()
        provider.files[url.path] = Data(json.utf8)

        let result = try await ConfigParser.parse(at: url, fileProvider: provider)
        #expect(result.filePath == url.path)
        #expect(result.fileType == .json)
        #expect(result.contentHash.count == 64)
        #expect(result.schema.keyPaths["key"] == .string)
        #expect(result.schema.keyPaths["count"] == .number)
        #expect(result.rawData == Data(json.utf8))
    }

    @Test("Parse Markdown file via mock provider")
    func parseMarkdown() async throws {
        let url = URL(fileURLWithPath: "/tmp/CLAUDE.md")
        let markdown = "# Title\n## Section\nContent"
        var provider = MockFileProvider()
        provider.files[url.path] = Data(markdown.utf8)

        let result = try await ConfigParser.parse(at: url, fileProvider: provider)
        #expect(result.fileType == .markdown)
        #expect(result.schema.headings.count == 2)
        #expect(result.schema.headings[0].text == "Title")
    }

    // MARK: - Error cases

    @Test("File too large throws error")
    func fileTooLarge() async {
        let url = URL(fileURLWithPath: "/tmp/large.json")
        var provider = MockFileProvider()
        provider.files[url.path] = Data(repeating: 0, count: 100)
        provider.fileSizes[url.path] = 2_000_000

        do {
            _ = try await ConfigParser.parse(at: url, fileProvider: provider, maxFileSize: 1_048_576)
            Issue.record("Expected fileTooLarge error")
        } catch let error as ConfigParserError {
            if case .fileTooLarge(_, let size) = error {
                #expect(size == 2_000_000)
            } else {
                Issue.record("Expected fileTooLarge, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("File not readable throws error")
    func fileNotReadable() async {
        let url = URL(fileURLWithPath: "/tmp/nonexistent.json")
        let provider = MockFileProvider()

        do {
            _ = try await ConfigParser.parse(at: url, fileProvider: provider)
            Issue.record("Expected fileNotReadable error")
        } catch let error as ConfigParserError {
            if case .fileNotReadable = error {
                // Expected
            } else {
                Issue.record("Expected fileNotReadable, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Malformed JSON throws error")
    func malformedJSON() async {
        let url = URL(fileURLWithPath: "/tmp/bad.json")
        var provider = MockFileProvider()
        provider.files[url.path] = Data("{invalid".utf8)

        do {
            _ = try await ConfigParser.parse(at: url, fileProvider: provider)
            Issue.record("Expected malformedJSON error")
        } catch let error as ConfigParserError {
            if case .malformedJSON = error {
                // Expected
            } else {
                Issue.record("Expected malformedJSON, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Unsupported file type throws error")
    func unsupportedType() async {
        let url = URL(fileURLWithPath: "/tmp/config.toml")
        var provider = MockFileProvider()
        provider.files[url.path] = Data("key = value".utf8)

        do {
            _ = try await ConfigParser.parse(at: url, fileProvider: provider)
            Issue.record("Expected unsupportedType error")
        } catch let error as ConfigParserError {
            if case .unsupportedType = error {
                // Expected
            } else {
                Issue.record("Expected unsupportedType, got \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - Real file system

    @Test("Parse real JSON file with DefaultFileProvider")
    func parseRealFile() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cck-parser-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        try "{\"test\": true}".write(to: url, atomically: true, encoding: .utf8)

        let result = try await ConfigParser.parse(at: url)
        #expect(result.fileType == .json)
        #expect(result.schema.keyPaths["test"] == .boolean)
    }
}
