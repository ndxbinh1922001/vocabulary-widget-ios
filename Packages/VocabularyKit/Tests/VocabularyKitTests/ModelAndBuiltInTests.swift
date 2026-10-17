import Foundation
import Testing

@testable import VocabularyKit

@Suite("VocabularyWord")
struct VocabularyWordTests {
    @Test("Codable round-trip keeps every field")
    func codableRoundTrip() throws {
        let word = Fixtures.word("b:ability", term: "ability")
        let data = try JSONEncoder().encode(word)
        let decoded = try JSONDecoder().decode(VocabularyWord.self, from: data)
        #expect(decoded == word)
    }

    @Test("Caption joins uppercased part of speech and IPA")
    func caption() {
        let full = VocabularyWord(
            id: "1", term: "calm", ipa: "/kɑːm/", partOfSpeech: "adjective", meaningVi: "x", source: .user)
        #expect(full.caption == "ADJECTIVE · /kɑːm/")

        let ipaOnly = VocabularyWord(id: "2", term: "calm", ipa: "/kɑːm/", meaningVi: "x", source: .user)
        #expect(ipaOnly.caption == "/kɑːm/")

        let none = VocabularyWord(id: "3", term: "calm", ipa: "", meaningVi: "x", source: .user)
        #expect(none.caption == nil)
    }
}

@Suite("Built-in vocabulary")
struct BuiltInVocabularyTests {
    @Test("Bundled list loads from the package resources")
    func loadsBundledList() {
        let words = BuiltInVocabulary.load()
        #expect(words.count >= 100)
        #expect(words.allSatisfy { $0.source == .builtIn })
    }

    @Test("Ids are unique, stable and prefixed")
    func uniqueIDs() {
        let words = BuiltInVocabulary.load()
        let ids = words.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(ids.allSatisfy { $0.hasPrefix("b:") })
    }

    @Test("Terms are unique ignoring case and diacritics")
    func uniqueTerms() {
        let keys = BuiltInVocabulary.load().map { WordValidator.comparisonKey(for: $0.term) }
        #expect(Set(keys).count == keys.count)
    }

    @Test("Every entry passes the same rules as user input")
    func entriesRespectLimits() {
        for word in BuiltInVocabulary.load() {
            let draft = WordDraft(word: word)
            #expect(draft.normalized == draft, "\(word.id) has untrimmed or doubled whitespace")
            let issues = WordValidator.validate(draft, existingWords: [], userWordCount: 0)
            #expect(issues.isEmpty, "\(word.id): \(issues)")
            #expect(word.ipa?.isEmpty == false, "\(word.id) is missing IPA")
            #expect(word.example?.isEmpty == false, "\(word.id) is missing an example")
        }
    }

    @Test("Malformed data throws instead of returning partial results")
    func malformedDataThrows() {
        #expect(throws: (any Error).self) {
            try BuiltInVocabulary.decode(Data("[{\"id\": \"b:x\"}]".utf8))
        }
    }
}
