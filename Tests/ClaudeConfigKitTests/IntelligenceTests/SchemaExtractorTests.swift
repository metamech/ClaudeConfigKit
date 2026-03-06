import Foundation
import Testing

@testable import ClaudeConfigKit

@Suite("SchemaExtractor Tests")
struct SchemaExtractorTests {

    // MARK: - JSON extraction

    @Test("Extract flat JSON key paths")
    func extractFlatJSON() throws {
        let json = """
        {"name": "test", "count": 42, "active": true}
        """.data(using: .utf8)!

        let schema = try SchemaExtractor.extractJSON(from: json)
        #expect(schema.keyPaths["name"] == .string)
        #expect(schema.keyPaths["count"] == .number)
        #expect(schema.keyPaths["active"] == .boolean)
        #expect(schema.fingerprint.count == 64)
    }

    @Test("Extract nested JSON key paths")
    func extractNestedJSON() throws {
        let json = """
        {"outer": {"inner": "value", "deep": {"leaf": 1}}}
        """.data(using: .utf8)!

        let schema = try SchemaExtractor.extractJSON(from: json)
        #expect(schema.keyPaths["outer"] == .object)
        #expect(schema.keyPaths["outer.inner"] == .string)
        #expect(schema.keyPaths["outer.deep"] == .object)
        #expect(schema.keyPaths["outer.deep.leaf"] == .number)
    }

    @Test("Extract JSON with arrays")
    func extractJSONWithArrays() throws {
        let json = """
        {"items": [{"id": 1}, {"id": 2}]}
        """.data(using: .utf8)!

        let schema = try SchemaExtractor.extractJSON(from: json)
        #expect(schema.keyPaths["items"] == .array)
        #expect(schema.keyPaths["items[].id"] == .number)
    }

    @Test("Fingerprint stability — same structure, same fingerprint")
    func fingerprintStability() throws {
        let json1 = """
        {"a": 1, "b": "hello"}
        """.data(using: .utf8)!

        let json2 = """
        {"b": "world", "a": 999}
        """.data(using: .utf8)!

        let schema1 = try SchemaExtractor.extractJSON(from: json1)
        let schema2 = try SchemaExtractor.extractJSON(from: json2)

        // Same keys and types, different values → same fingerprint
        #expect(schema1.fingerprint == schema2.fingerprint)
    }

    @Test("Different structures produce different fingerprints")
    func differentStructuresDifferentFingerprints() throws {
        let json1 = """
        {"a": 1}
        """.data(using: .utf8)!

        let json2 = """
        {"a": 1, "b": 2}
        """.data(using: .utf8)!

        let schema1 = try SchemaExtractor.extractJSON(from: json1)
        let schema2 = try SchemaExtractor.extractJSON(from: json2)

        #expect(schema1.fingerprint != schema2.fingerprint)
    }

    @Test("Extract JSON with null values")
    func extractJSONWithNull() throws {
        let json = """
        {"key": null}
        """.data(using: .utf8)!

        let schema = try SchemaExtractor.extractJSON(from: json)
        #expect(schema.keyPaths["key"] == .null)
    }

    // MARK: - Markdown extraction

    @Test("Extract Markdown headings")
    func extractMarkdownHeadings() {
        let markdown = """
        # Title
        Some text
        ## Section 1
        Content
        ### Subsection
        More content
        ## Section 2
        """

        let schema = SchemaExtractor.extractMarkdown(from: markdown)
        #expect(schema.headings.count == 4)
        #expect(schema.headings[0] == "Title")
        #expect(schema.headings[1] == "Section 1")
        #expect(schema.headings[2] == "Subsection")
        #expect(schema.headings[3] == "Section 2")
        #expect(schema.fingerprint.count == 64)
    }

    @Test("Markdown heading fingerprint stability")
    func markdownFingerprintStability() {
        let md1 = "# Hello\n## World"
        let md2 = "# Hello\nDifferent content\n## World\nMore different content"

        let schema1 = SchemaExtractor.extractMarkdown(from: md1)
        let schema2 = SchemaExtractor.extractMarkdown(from: md2)

        // Same headings → same fingerprint
        #expect(schema1.fingerprint == schema2.fingerprint)
    }

    @Test("Empty Markdown produces empty headings")
    func emptyMarkdown() {
        let schema = SchemaExtractor.extractMarkdown(from: "No headings here.\nJust plain text.")
        #expect(schema.headings.isEmpty)
    }
}
