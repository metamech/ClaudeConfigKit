import Foundation
import Testing

@testable import ClaudeConfigKit

@Suite("SlugPathEncoder")
struct SlugPathEncoderTests {

    @Test("Encodes absolute path by replacing / with - and dropping leading -")
    func encodeAbsolutePath() {
        let result = SlugPathEncoder.encodeProjectPath("/Users/ion/project")
        #expect(result == "Users-ion-project")
    }

    @Test("Encodes path without leading slash")
    func encodeRelativePath() {
        let result = SlugPathEncoder.encodeProjectPath("Users/ion/project")
        #expect(result == "Users-ion-project")
    }

    @Test("Encodes root path")
    func encodeRootPath() {
        let result = SlugPathEncoder.encodeProjectPath("/")
        #expect(result == "")
    }

    @Test("Encodes single component path")
    func encodeSingleComponent() {
        let result = SlugPathEncoder.encodeProjectPath("/home")
        #expect(result == "home")
    }

    @Test("jsonlFileURL builds correct path")
    func jsonlFileURL() {
        let url = SlugPathEncoder.jsonlFileURL(
            sessionId: "abc-123",
            workingDirectory: "/Users/ion/project"
        )
        #expect(url.lastPathComponent == "abc-123.jsonl")
        #expect(url.pathComponents.contains("Users-ion-project"))
        #expect(url.pathComponents.contains(".claude"))
        #expect(url.pathComponents.contains("projects"))
    }
}
