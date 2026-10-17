import Foundation

/// Fields the user can edit for their own words.
public enum WordField: String, Sendable, CaseIterable {
    case term
    case ipa
    case partOfSpeech
    case meaningVi
    case example

    /// Maximum number of characters (grapheme clusters) accepted after normalization.
    public var maxLength: Int {
        switch self {
        case .term: 60
        case .ipa: 60
        case .partOfSpeech: 20
        case .meaningVi: 200
        case .example: 300
        }
    }

    public var isRequired: Bool {
        self == .term || self == .meaningVi
    }
}

/// Raw input from the add/edit form. Empty strings mean "not provided".
public struct WordDraft: Equatable, Sendable {
    public var term: String
    public var ipa: String
    public var partOfSpeech: String
    public var meaningVi: String
    public var example: String

    public init(
        term: String = "",
        ipa: String = "",
        partOfSpeech: String = "",
        meaningVi: String = "",
        example: String = ""
    ) {
        self.term = term
        self.ipa = ipa
        self.partOfSpeech = partOfSpeech
        self.meaningVi = meaningVi
        self.example = example
    }

    /// Prefills the form from an existing word.
    public init(word: VocabularyWord) {
        self.init(
            term: word.term,
            ipa: word.ipa ?? "",
            partOfSpeech: word.partOfSpeech ?? "",
            meaningVi: word.meaningVi,
            example: word.example ?? ""
        )
    }

    public subscript(field: WordField) -> String {
        get {
            switch field {
            case .term: term
            case .ipa: ipa
            case .partOfSpeech: partOfSpeech
            case .meaningVi: meaningVi
            case .example: example
            }
        }
        set {
            switch field {
            case .term: term = newValue
            case .ipa: ipa = newValue
            case .partOfSpeech: partOfSpeech = newValue
            case .meaningVi: meaningVi = newValue
            case .example: example = newValue
            }
        }
    }

    /// Copy with every field trimmed and inner whitespace (including newlines) collapsed to single spaces.
    public var normalized: WordDraft {
        var copy = self
        for field in WordField.allCases {
            copy[field] = WordValidator.normalize(self[field])
        }
        return copy
    }
}

/// A reason why a draft cannot be saved.
public enum WordValidationIssue: Equatable, Sendable {
    case required(WordField)
    case tooLong(WordField, limit: Int)
    /// Another word already uses the same term (ignoring case and diacritics).
    case duplicateTerm
    /// The user already stores the maximum number of words.
    case limitReached(max: Int)

    /// The form field the issue belongs to, or `nil` for form-level issues.
    public var field: WordField? {
        switch self {
        case .required(let field), .tooLong(let field, _): field
        case .duplicateTerm: .term
        case .limitReached: nil
        }
    }
}

public enum WordValidator {
    /// Upper bound for user-created words, keeping the shared file and widget work small.
    public static let maxUserWords = 5_000

    /// Trims the text and collapses every whitespace run to a single space.
    public static func normalize(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// Key used to detect duplicate terms: normalized, case-, diacritic- and width-insensitive.
    public static func comparisonKey(for term: String) -> String {
        normalize(term).folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    /// Validates `draft` against the words that already exist.
    ///
    /// - Parameters:
    ///   - existingWords: Built-in and user words used for the duplicate check.
    ///   - userWordCount: Number of stored user words, used for the size cap when adding.
    ///   - editingID: Id of the word being edited; it is ignored by the duplicate check and the cap.
    public static func validate(
        _ draft: WordDraft,
        existingWords: [VocabularyWord],
        userWordCount: Int,
        editingID: String? = nil
    ) -> [WordValidationIssue] {
        let normalized = draft.normalized
        var issues: [WordValidationIssue] = []

        for field in WordField.allCases {
            let value = normalized[field]
            if field.isRequired && value.isEmpty {
                issues.append(.required(field))
            } else if value.count > field.maxLength {
                issues.append(.tooLong(field, limit: field.maxLength))
            }
        }

        if !normalized.term.isEmpty {
            let key = comparisonKey(for: normalized.term)
            let isDuplicate = existingWords.contains { word in
                word.id != editingID && comparisonKey(for: word.term) == key
            }
            if isDuplicate {
                issues.append(.duplicateTerm)
            }
        }

        if editingID == nil && userWordCount >= maxUserWords {
            issues.append(.limitReached(max: maxUserWords))
        }

        return issues
    }
}
