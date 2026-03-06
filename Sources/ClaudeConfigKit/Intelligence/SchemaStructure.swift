import Foundation

// MARK: - SchemaValueType

/// The JSON type of a value at a key path in a schema structure.
public enum SchemaValueType: String, Codable, Sendable {
    case string
    case number
    case boolean
    case null
    case array
    case object
}

// MARK: - SchemaStructure

/// Structural skeleton of a configuration file.
///
/// For JSON files, captures the set of key paths and their value types.
/// For Markdown files, captures the heading hierarchy.
/// The `fingerprint` is a SHA-256 hash of the structural information,
/// enabling cheap equality checks for schema-level changes.
public struct SchemaStructure: Codable, Sendable, Equatable {

    /// Key paths mapped to their JSON value types (for JSON configs).
    public var keyPaths: [String: SchemaValueType]

    /// Heading strings extracted from Markdown configs (in document order).
    public var headings: [String]

    /// SHA-256 fingerprint of the structural information.
    public var fingerprint: String

    public init(keyPaths: [String: SchemaValueType] = [:], headings: [String] = [], fingerprint: String = "") {
        self.keyPaths = keyPaths
        self.headings = headings
        self.fingerprint = fingerprint
    }
}
