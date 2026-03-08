import Foundation

// MARK: - FileProvider

/// Abstraction for file system operations, enabling testing with mock providers.
public protocol FileProvider: Sendable {
    func read(at url: URL) async throws -> Data
    func exists(at url: URL) async -> Bool
    func size(of url: URL) async throws -> UInt64
}

// MARK: - DefaultFileProvider

/// Default file provider using Foundation's FileManager.
public struct DefaultFileProvider: FileProvider, Sendable {
    public init() {}

    public func read(at url: URL) async throws -> Data {
        try await FileHasher.readFileData(at: url)
    }

    public func exists(at url: URL) async -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    public func size(of url: URL) async throws -> UInt64 {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs[.size] as? UInt64) ?? 0
    }
}

// MARK: - ConfigFileType

/// Recognized config file formats.
public enum ConfigFileType: String, Sendable, Codable {
    case json
    case jsonl
    case markdown
    case yaml
    case unknown
}

// MARK: - ConfigParserError

/// Errors thrown by ``ConfigParser``.
public enum ConfigParserError: Error, Sendable {
    case fileTooLarge(URL, UInt64)
    case malformedJSON(URL, any Error)
    case fileNotReadable(URL)
    case unsupportedType(URL, String)
}

// MARK: - ParsedConfig

/// Result of parsing a configuration file.
public struct ParsedConfig: Sendable {
    /// Path to the parsed file.
    public let filePath: String
    /// Detected file type.
    public let fileType: ConfigFileType
    /// SHA-256 hash of the raw content.
    public let contentHash: String
    /// Extracted structural schema.
    public let schema: SchemaStructure
    /// Raw file data.
    public let rawData: Data

    public init(filePath: String, fileType: ConfigFileType, contentHash: String, schema: SchemaStructure, rawData: Data) {
        self.filePath = filePath
        self.fileType = fileType
        self.contentHash = contentHash
        self.schema = schema
        self.rawData = rawData
    }
}

// MARK: - ConfigParser

/// Generic config file parser that reads, hashes, detects type, and extracts schema.
public enum ConfigParser: Sendable {

    /// Default maximum file size (1 MB).
    public static let defaultMaxFileSize: UInt64 = 1_048_576

    /// Parse a config file at the given URL.
    ///
    /// - Parameters:
    ///   - url: The file to parse.
    ///   - fileProvider: Provider for file I/O (default: ``DefaultFileProvider``).
    ///   - maxFileSize: Maximum allowed file size in bytes.
    /// - Returns: A ``ParsedConfig`` with hash, schema, and raw data.
    /// - Throws: ``ConfigParserError`` on failure.
    public static func parse(
        at url: URL,
        fileProvider: any FileProvider = DefaultFileProvider(),
        maxFileSize: UInt64 = defaultMaxFileSize
    ) async throws -> ParsedConfig {
        guard await fileProvider.exists(at: url) else {
            throw ConfigParserError.fileNotReadable(url)
        }

        let fileSize = try await fileProvider.size(of: url)
        if fileSize > maxFileSize {
            throw ConfigParserError.fileTooLarge(url, fileSize)
        }

        let data = try await fileProvider.read(at: url)
        let hash = FileHasher.hash(data: data)
        let fileType = detectFileType(for: url)

        let schema: SchemaStructure
        switch fileType {
        case .json:
            do {
                schema = try SchemaExtractor.extractJSON(from: data)
            } catch {
                throw ConfigParserError.malformedJSON(url, error)
            }
        case .jsonl:
            // For JSONL, extract schema from first line
            if let firstLine = String(data: data, encoding: .utf8)?
                .components(separatedBy: .newlines)
                .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
               let lineData = firstLine.data(using: .utf8) {
                schema = (try? SchemaExtractor.extractJSON(from: lineData)) ?? SchemaStructure()
            } else {
                schema = SchemaStructure()
            }
        case .markdown:
            let content = String(data: data, encoding: .utf8) ?? ""
            schema = SchemaExtractor.extractMarkdown(from: content)
        case .yaml:
            // YAML parsing not yet implemented — return empty schema
            schema = SchemaStructure()
        case .unknown:
            throw ConfigParserError.unsupportedType(url, url.pathExtension)
        }

        return ParsedConfig(
            filePath: url.path,
            fileType: fileType,
            contentHash: hash,
            schema: schema,
            rawData: data
        )
    }

    /// Detect the config file type from the URL's extension.
    public static func detectFileType(for url: URL) -> ConfigFileType {
        switch url.pathExtension.lowercased() {
        case "json":
            return .json
        case "jsonl":
            return .jsonl
        case "md", "markdown":
            return .markdown
        case "yaml", "yml":
            return .yaml
        default:
            return .unknown
        }
    }
}
