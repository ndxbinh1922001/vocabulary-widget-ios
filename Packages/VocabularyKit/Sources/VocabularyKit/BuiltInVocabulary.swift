import Foundation
import os

/// The read-only word list that ships with the app (`Resources/builtin_words.json`).
public enum BuiltInVocabulary {
    public static let resourceName = "builtin_words"

    private static let logger = Logger(subsystem: "VocabularyKit", category: "BuiltInVocabulary")

    /// Name of the resource bundle SwiftPM and Xcode generate for this target.
    private static let resourceBundleName = "VocabularyKit_VocabularyKit.bundle"

    private struct Entry: Decodable {
        let id: String
        let term: String
        let ipa: String?
        let partOfSpeech: String?
        let meaningVi: String
        let example: String?
    }

    /// Decodes the bundled JSON array. Throws on malformed data so tests can assert integrity.
    public static func decode(_ data: Data) throws -> [VocabularyWord] {
        try JSONDecoder().decode([Entry].self, from: data).map { entry in
            VocabularyWord(
                id: entry.id,
                term: entry.term,
                ipa: entry.ipa,
                partOfSpeech: entry.partOfSpeech,
                meaningVi: entry.meaningVi,
                example: entry.example,
                source: .builtIn
            )
        }
    }

    /// Loads the bundled list. Returns an empty list instead of crashing when the resource
    /// bundle is missing or the JSON is malformed, so the widget can still render a placeholder.
    public static func load() -> [VocabularyWord] {
        guard let url = resourceURL() else {
            logger.error("builtin_words.json not found in any candidate bundle")
            return []
        }
        do {
            return try decode(Data(contentsOf: url))
        } catch {
            logger.error("Failed to load built-in words: \(String(describing: error), privacy: .public)")
            return []
        }
    }

    /// Locates `builtin_words.json` without touching `Bundle.module`, whose generated accessor
    /// calls `fatalError` when the resource bundle cannot be found.
    static func resourceURL() -> URL? {
        let codeBundle = Bundle(for: BundleToken.self)
        let candidateDirectories = [
            Bundle.main.resourceURL,
            Bundle.main.bundleURL,
            codeBundle.resourceURL,
            codeBundle.bundleURL.deletingLastPathComponent(),
        ]
        for case let directory? in candidateDirectories {
            let bundleURL = directory.appendingPathComponent(resourceBundleName)
            if let bundle = Bundle(url: bundleURL),
                let url = bundle.url(forResource: resourceName, withExtension: "json")
            {
                return url
            }
        }
        return nil
    }
}

/// Anchor class used to find the bundle this code was linked into.
private final class BundleToken {}
