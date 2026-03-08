import Foundation
import CryptoKit

// MARK: - FileHasher

/// Namespace for SHA-256 hashing utilities.
public enum FileHasher: Sendable {

    /// Returns the SHA-256 hex digest of `data`.
    public static func hash(data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Returns the SHA-256 hex digest of the file at `url`.
    public static func hash(fileAt url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return hash(data: data)
    }

    /// Returns the SHA-256 hex digest of the file at `url` asynchronously.
    public static func hash(fileAt url: URL) async throws -> String {
        let data = try await readFileData(at: url)
        return hash(data: data)
    }

    /// Reads file data off the calling actor's executor.
    internal static func readFileData(at url: URL) async throws -> Data {
        try await Task.detached(priority: .utility) {
            try Data(contentsOf: url)
        }.value
    }
}
