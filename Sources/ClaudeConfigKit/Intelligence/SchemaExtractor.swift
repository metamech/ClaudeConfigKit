import Foundation
import CryptoKit

// MARK: - SchemaExtractor

/// Extracts structural schemas from JSON and Markdown configuration files.
public enum SchemaExtractor: Sendable {

    /// Extract a ``SchemaStructure`` from JSON data.
    ///
    /// Recursively walks the JSON object tree, collecting key paths and their
    /// value types. The fingerprint is the SHA-256 hash of the sorted key paths
    /// concatenated with their types.
    public static func extractJSON(from data: Data) throws -> SchemaStructure {
        let object = try JSONSerialization.jsonObject(with: data)
        var keyPaths: [String: SchemaValueType] = [:]
        walkJSON(object, prefix: "", into: &keyPaths)

        let fingerprint = computeFingerprint(keyPaths: keyPaths)
        return SchemaStructure(keyPaths: keyPaths, headings: [], fingerprint: fingerprint)
    }

    /// Extract a ``SchemaStructure`` from Markdown content.
    ///
    /// Scans for ATX headings (`# ` through `###### `) and collects them in
    /// document order. The fingerprint is the SHA-256 hash of the heading list.
    public static func extractMarkdown(from content: String) -> SchemaStructure {
        var headings: [String] = []

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let match = trimmed.range(of: #"^#{1,6}\s+"#, options: .regularExpression) {
                let heading = String(trimmed[match.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !heading.isEmpty {
                    headings.append(heading)
                }
            }
        }

        let fingerprint = computeHeadingFingerprint(headings: headings)
        return SchemaStructure(keyPaths: [:], headings: headings, fingerprint: fingerprint)
    }

    // MARK: - Private

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
            // CFBoolean and NSNumber are toll-free bridged; use CFType check
            // to distinguish JSON booleans from numbers.
            if CFGetTypeID(num) == CFBooleanGetTypeID() {
                keyPaths[prefix.isEmpty ? "$" : prefix] = .boolean
            } else {
                keyPaths[prefix.isEmpty ? "$" : prefix] = .number
            }
        } else if value is NSNull {
            keyPaths[prefix.isEmpty ? "$" : prefix] = .null
        }
    }

    private static func computeFingerprint(keyPaths: [String: SchemaValueType]) -> String {
        let sorted = keyPaths.sorted { $0.key < $1.key }
        let representation = sorted.map { "\($0.key):\($0.value.rawValue)" }.joined(separator: "\n")
        let data = Data(representation.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func computeHeadingFingerprint(headings: [String]) -> String {
        let representation = headings.joined(separator: "\n")
        let data = Data(representation.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
