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

// MARK: - Heading

/// A Markdown heading with its level (1-6) and text.
public struct Heading: Sendable, Codable, Equatable, Hashable {
    /// Heading level (1 for `#`, 2 for `##`, etc.).
    public let level: Int
    /// The heading text (without `#` prefix).
    public let text: String

    public init(level: Int, text: String) {
        self.level = level
        self.text = text
    }
}

// MARK: - SchemaNode

/// Recursive representation of a JSON schema tree.
public indirect enum SchemaNode: Sendable, Codable, Equatable, Hashable {
    case null
    case bool
    case number
    case string
    case array(SchemaNode?)
    case object([String: SchemaNode])
}

// MARK: - SchemaStructure

/// Structural skeleton of a configuration file.
///
/// For JSON files, captures the set of key paths and their value types,
/// plus an optional recursive `tree` representation.
/// For Markdown files, captures the heading hierarchy with levels.
/// The `fingerprint` is a SHA-256 hash of the structural information,
/// enabling cheap equality checks for schema-level changes.
public struct SchemaStructure: Codable, Sendable, Equatable {

    /// Key paths mapped to their JSON value types (for JSON configs).
    public var keyPaths: [String: SchemaValueType]

    /// Headings extracted from Markdown configs (in document order), with levels.
    public var headings: [Heading]

    /// SHA-256 fingerprint of the structural information.
    public var fingerprint: String

    /// Whether the Markdown file has YAML frontmatter.
    public var hasYAMLFrontMatter: Bool

    /// Recursive schema tree for JSON configs.
    public var tree: SchemaNode?

    public init(
        keyPaths: [String: SchemaValueType] = [:],
        headings: [Heading] = [],
        fingerprint: String = "",
        hasYAMLFrontMatter: Bool = false,
        tree: SchemaNode? = nil
    ) {
        self.keyPaths = keyPaths
        self.headings = headings
        self.fingerprint = fingerprint
        self.hasYAMLFrontMatter = hasYAMLFrontMatter
        self.tree = tree
    }
}
