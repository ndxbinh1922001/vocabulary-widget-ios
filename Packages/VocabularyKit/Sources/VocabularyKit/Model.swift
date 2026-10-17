import Foundation

/// Where a word comes from. Built-in words ship with the app and are read-only.
public enum WordSource: String, Codable, Sendable, CaseIterable {
    case builtIn
    case user
}

/// A single vocabulary entry shown in the app and in the widgets.
///
/// Example:
/// ```swift
/// let word = VocabularyWord(
///     id: "b:ability", term: "ability", ipa: "/əˈbɪləti/", partOfSpeech: "noun",
///     meaningVi: "khả năng, năng lực", example: "She has the ability to learn quickly.",
///     source: .builtIn)
/// ```
public struct VocabularyWord: Codable, Hashable, Identifiable, Sendable {
    /// Stable identifier. Built-in words use `"b:<slug>"`, user words a UUID string.
    /// Rotation order is derived from this value, so it must never change for a stored word.
    public let id: String
    public var term: String
    public var ipa: String?
    public var partOfSpeech: String?
    public var meaningVi: String
    public var example: String?
    public var source: WordSource

    public init(
        id: String,
        term: String,
        ipa: String? = nil,
        partOfSpeech: String? = nil,
        meaningVi: String,
        example: String? = nil,
        source: WordSource
    ) {
        self.id = id
        self.term = term
        self.ipa = ipa
        self.partOfSpeech = partOfSpeech
        self.meaningVi = meaningVi
        self.example = example
        self.source = source
    }

    /// Uppercased caption such as `"NOUN · /əˈbɪləti/"`, or `nil` when both parts are missing.
    public var caption: String? {
        let parts = [partOfSpeech?.uppercased(), ipa].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
