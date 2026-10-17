import Foundation
import Testing

@testable import VocabularyKit

@Suite("WordValidator")
struct WordValidatorTests {
    private let existing = [
        Fixtures.word("b:ability", term: "ability"),
        Fixtures.word("b:cafe", term: "café"),
        Fixtures.word("u1", term: "resilience", source: .user),
    ]

    private func validDraft(term: String = "serendipity") -> WordDraft {
        WordDraft(term: term, ipa: "/ˌserənˈdɪpəti/", partOfSpeech: "noun", meaningVi: "sự tình cờ may mắn")
    }

    @Test("normalize trims and collapses whitespace including newlines")
    func normalize() {
        #expect(WordValidator.normalize("  hello \n\t  world  ") == "hello world")
        #expect(WordValidator.normalize("   ") == "")
    }

    @Test("A complete draft has no issues")
    func validDraftPasses() {
        #expect(WordValidator.validate(validDraft(), existingWords: existing, userWordCount: 1).isEmpty)
    }

    @Test("Term and Vietnamese meaning are required; whitespace-only counts as empty")
    func requiredFields() {
        let draft = WordDraft(term: "   ", meaningVi: "\n")
        let issues = WordValidator.validate(draft, existingWords: [], userWordCount: 0)
        #expect(issues == [.required(.term), .required(.meaningVi)])
    }

    @Test("Length limits apply after normalization", arguments: WordField.allCases)
    func lengthLimits(field: WordField) {
        var atLimit = validDraft()
        atLimit[field] = String(repeating: "a", count: field.maxLength)
        #expect(WordValidator.validate(atLimit, existingWords: [], userWordCount: 0).isEmpty)

        var overLimit = validDraft()
        overLimit[field] = String(repeating: "a", count: field.maxLength + 1)
        #expect(
            WordValidator.validate(overLimit, existingWords: [], userWordCount: 0)
                == [.tooLong(field, limit: field.maxLength)])

        var paddedAtLimit = validDraft()
        paddedAtLimit[field] = "   " + String(repeating: "a", count: field.maxLength) + "   "
        #expect(WordValidator.validate(paddedAtLimit, existingWords: [], userWordCount: 0).isEmpty)
    }

    @Test("Vietnamese diacritics count as single characters")
    func vietnameseCharacterCount() {
        var draft = validDraft()
        draft.meaningVi = String(repeating: "ữ", count: WordField.meaningVi.maxLength)
        #expect(WordValidator.validate(draft, existingWords: [], userWordCount: 0).isEmpty)
    }

    @Test(
        "Duplicate terms are detected ignoring case, diacritics and spacing",
        arguments: ["Ability", " ABILITY ", "cafe", "Resilience"])
    func duplicates(term: String) {
        let issues = WordValidator.validate(validDraft(term: term), existingWords: existing, userWordCount: 1)
        #expect(issues == [.duplicateTerm])
    }

    @Test("Editing a word does not conflict with itself")
    func editingIgnoresOwnTerm() {
        let issues = WordValidator.validate(
            validDraft(term: "RESILIENCE"), existingWords: existing, userWordCount: 1, editingID: "u1")
        #expect(issues.isEmpty)
    }

    @Test("The user word cap blocks adding but not editing")
    func userWordCap() {
        let cap = WordValidator.maxUserWords
        #expect(
            WordValidator.validate(validDraft(), existingWords: [], userWordCount: cap)
                == [.limitReached(max: cap)])
        #expect(WordValidator.validate(validDraft(), existingWords: [], userWordCount: cap - 1).isEmpty)
        #expect(WordValidator.validate(validDraft(), existingWords: [], userWordCount: cap, editingID: "u1").isEmpty)
    }

    @Test("Issues map to their form field")
    func issueFields() {
        #expect(WordValidationIssue.required(.meaningVi).field == .meaningVi)
        #expect(WordValidationIssue.tooLong(.example, limit: 300).field == .example)
        #expect(WordValidationIssue.duplicateTerm.field == .term)
        #expect(WordValidationIssue.limitReached(max: 1).field == nil)
    }
}
