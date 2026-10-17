import Foundation

public enum WordLibraryError: Error, Equatable, Sendable {
    case invalid([WordValidationIssue])
    case notFound
    /// Built-in words cannot be edited or deleted.
    case readOnly
}

/// In-memory view of all words: the read-only built-in list plus the user's own words.
///
/// Mutations validate input and only ever touch `userWords`; persisting the result is
/// the caller's job (see `VocabularyStorage`).
public struct WordLibrary: Equatable, Sendable {
    public private(set) var builtInWords: [VocabularyWord]
    public private(set) var userWords: [VocabularyWord]

    public init(builtInWords: [VocabularyWord], userWords: [VocabularyWord]) {
        self.builtInWords = builtInWords
        self.userWords = userWords
    }

    public var allWords: [VocabularyWord] {
        builtInWords + userWords
    }

    public func word(id: String) -> VocabularyWord? {
        allWords.first { $0.id == id }
    }

    public func words(in filter: WordSourceFilter) -> [VocabularyWord] {
        allWords.filter(filter.includes)
    }

    /// Words in `filter` whose term or meaning contains `query`, ignoring case and diacritics,
    /// sorted by term. An empty query returns every word in `filter`.
    public func search(_ query: String, in filter: WordSourceFilter) -> [VocabularyWord] {
        let needle = WordValidator.normalize(query)
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]
        return words(in: filter)
            .filter { word in
                needle.isEmpty
                    || word.term.range(of: needle, options: options) != nil
                    || word.meaningVi.range(of: needle, options: options) != nil
            }
            .sorted { lhs, rhs in
                let order = lhs.term.localizedCaseInsensitiveCompare(rhs.term)
                return order == .orderedSame ? lhs.id < rhs.id : order == .orderedAscending
            }
    }

    public func validate(_ draft: WordDraft, editingID: String? = nil) -> [WordValidationIssue] {
        WordValidator.validate(
            draft,
            existingWords: allWords,
            userWordCount: userWords.count,
            editingID: editingID
        )
    }

    /// Adds a new user word built from the normalized draft.
    @discardableResult
    public mutating func addWord(_ draft: WordDraft, id: String = UUID().uuidString) throws(WordLibraryError)
        -> VocabularyWord
    {
        let issues = validate(draft)
        guard issues.isEmpty else { throw .invalid(issues) }
        let word = Self.makeWord(id: id, from: draft.normalized)
        userWords.append(word)
        return word
    }

    /// Replaces the content of an existing user word, keeping its id.
    @discardableResult
    public mutating func updateWord(id: String, with draft: WordDraft) throws(WordLibraryError) -> VocabularyWord {
        guard let index = userWords.firstIndex(where: { $0.id == id }) else {
            throw builtInWords.contains(where: { $0.id == id }) ? .readOnly : .notFound
        }
        let issues = validate(draft, editingID: id)
        guard issues.isEmpty else { throw .invalid(issues) }
        let word = Self.makeWord(id: id, from: draft.normalized)
        userWords[index] = word
        return word
    }

    public mutating func deleteWord(id: String) throws(WordLibraryError) {
        guard let index = userWords.firstIndex(where: { $0.id == id }) else {
            throw builtInWords.contains(where: { $0.id == id }) ? .readOnly : .notFound
        }
        userWords.remove(at: index)
    }

    private static func makeWord(id: String, from draft: WordDraft) -> VocabularyWord {
        VocabularyWord(
            id: id,
            term: draft.term,
            ipa: draft.ipa.isEmpty ? nil : draft.ipa,
            partOfSpeech: draft.partOfSpeech.isEmpty ? nil : draft.partOfSpeech,
            meaningVi: draft.meaningVi,
            example: draft.example.isEmpty ? nil : draft.example,
            source: .user
        )
    }
}
