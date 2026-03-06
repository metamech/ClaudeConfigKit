import Foundation

// MARK: - ChangeClassifier

/// Classifies configuration changes by comparing baselines against current state.
public enum ChangeClassifier: Sendable {

    /// Classify a change given an optional previous baseline and optional current data.
    ///
    /// - Parameters:
    ///   - previousBaseline: The baseline snapshot from before (nil if file is new).
    ///   - currentData: The current file contents (nil if file was removed).
    ///   - currentURL: The URL of the file being checked.
    /// - Returns: The ``ChangeType`` classification.
    public static func classify(
        previousBaseline: ConfigBaseline?,
        currentData: Data?,
        currentURL: URL
    ) -> ChangeType {
        switch (previousBaseline, currentData) {
        case (nil, .some):
            return .fileAdded
        case (.some, nil):
            return .fileRemoved
        case let (.some(baseline), .some(data)):
            let currentHash = FileHasher.hash(data: data)
            guard currentHash != baseline.contentHash else {
                // No change at all — caller should check for this
                return .dataChange
            }

            // Try to extract schema and compare fingerprints
            let currentSchema = extractSchema(from: data, url: currentURL)
            if currentSchema.fingerprint != baseline.schema.fingerprint {
                return .schemaChange
            }
            return .dataChange
        case (nil, nil):
            return .fileRemoved
        }
    }

    // MARK: - Private

    private static func extractSchema(from data: Data, url: URL) -> SchemaStructure {
        let ext = url.pathExtension.lowercased()
        if ext == "json" || ext == "jsonl" {
            return (try? SchemaExtractor.extractJSON(from: data)) ?? SchemaStructure()
        } else if ext == "md" || ext == "markdown" {
            let content = String(data: data, encoding: .utf8) ?? ""
            return SchemaExtractor.extractMarkdown(from: content)
        }
        return SchemaStructure()
    }
}
