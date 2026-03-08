import Foundation
import CryptoKit

// MARK: - SchemaExtractor

/// Extracts structural schemas from JSON and Markdown configuration files.
public enum SchemaExtractor: Sendable {

    /// Extract a ``SchemaStructure`` from JSON data.
    ///
    /// Recursively walks the JSON object tree, collecting key paths and their
    /// value types, plus a recursive ``SchemaNode`` tree.
    public static func extractJSON(from data: Data) throws -> SchemaStructure {
        let object = try JSONSerialization.jsonObject(with: data)
        var keyPaths: [String: SchemaValueType] = [:]
        walkJSON(object, prefix: "", into: &keyPaths)

        let tree = buildSchemaNode(from: object)
        let fingerprint = computeTreeFingerprint(tree: tree)

        return SchemaStructure(
            keyPaths: keyPaths,
            headings: [],
            fingerprint: fingerprint,
            tree: tree
        )
    }

    /// Extract a ``SchemaStructure`` from Markdown content.
    ///
    /// Scans for ATX headings (`# ` through `###### `) and collects them in
    /// document order with their levels. Detects YAML frontmatter.
    public static func extractMarkdown(from content: String) -> SchemaStructure {
        var headings: [Heading] = []
        let hasYAMLFrontMatter = detectYAMLFrontMatter(in: content)

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let match = trimmed.range(of: #"^(#{1,6})\s+"#, options: .regularExpression) {
                let hashPart = trimmed[trimmed.startIndex..<match.upperBound]
                    .trimmingCharacters(in: .whitespaces)
                let level = hashPart.filter { $0 == "#" }.count
                let text = String(trimmed[match.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    headings.append(Heading(level: level, text: text))
                }
            }
        }

        let fingerprint = computeHeadingFingerprint(headings: headings)
        return SchemaStructure(
            keyPaths: [:],
            headings: headings,
            fingerprint: fingerprint,
            hasYAMLFrontMatter: hasYAMLFrontMatter
        )
    }

    // MARK: - Private — JSON walking

    private static func walkJSON(_ value: Any, prefix: String, into keyPaths: inout [String: SchemaValueType]) {
        if let dict = value as? [String: Any] {
            if prefix.isEmpty {
                keyPaths[prefix.isEmpty ? "$" : prefix] = .object
            } else {
                keyPaths[prefix] = .object
            }
            for (key, val) in dict {
                let path = prefix.isEmpty ? key : "\(prefix).\(key)"
                walkJSON(val, prefix: path, into: &keyPaths)
            }
        } else if let arr = value as? [Any] {
            keyPaths[prefix.isEmpty ? "$" : prefix] = .array
            if let first = arr.first {
                let itemPath = (prefix.isEmpty ? "$" : prefix) + "[]"
                walkJSON(first, prefix: itemPath, into: &keyPaths)
            }
        } else if value is String {
            keyPaths[prefix.isEmpty ? "$" : prefix] = .string
        } else if let num = value as? NSNumber {
            if CFGetTypeID(num) == CFBooleanGetTypeID() {
                keyPaths[prefix.isEmpty ? "$" : prefix] = .boolean
            } else {
                keyPaths[prefix.isEmpty ? "$" : prefix] = .number
            }
        } else if value is NSNull {
            keyPaths[prefix.isEmpty ? "$" : prefix] = .null
        }
    }

    // MARK: - Private — SchemaNode building

    private static func buildSchemaNode(from value: Any) -> SchemaNode {
        if let dict = value as? [String: Any] {
            var children: [String: SchemaNode] = [:]
            for (key, val) in dict {
                children[key] = buildSchemaNode(from: val)
            }
            return .object(children)
        } else if let arr = value as? [Any] {
            let element = arr.first.map { buildSchemaNode(from: $0) }
            return .array(element)
        } else if value is String {
            return .string
        } else if let num = value as? NSNumber {
            if CFGetTypeID(num) == CFBooleanGetTypeID() {
                return .bool
            } else {
                return .number
            }
        } else if value is NSNull {
            return .null
        }
        return .null
    }

    // MARK: - Private — YAML frontmatter detection

    private static func detectYAMLFrontMatter(in content: String) -> Bool {
        guard content.hasPrefix("---") else { return false }
        let afterFirst = content.dropFirst(3)
        guard let newlineIdx = afterFirst.firstIndex(where: { $0 == "\n" || $0 == "\r" }) else { return false }
        let rest = afterFirst[afterFirst.index(after: newlineIdx)...]
        return rest.contains("---")
    }

    // MARK: - Private — Fingerprints

    private static func computeTreeFingerprint(tree: SchemaNode) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(tree) else {
            return ""
        }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func computeHeadingFingerprint(headings: [Heading]) -> String {
        let representation = headings.map { "\($0.level):\($0.text)" }.joined(separator: "\n")
        let data = Data(representation.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
