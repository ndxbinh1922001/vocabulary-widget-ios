import Foundation
import Testing

@testable import VocabularyKit

@Suite("WordLibrary")
struct WordLibraryTests {
    private func makeLibrary() -> WordLibrary {
        WordLibrary(
            builtInWords: [
                VocabularyWord(id: "b:calm", term: "calm", meaningVi: "bình tĩnh", source: .builtIn),
                VocabularyWord(id: "b:ability", term: "ability", meaningVi: "khả năng", source: .builtIn),
            ],
            userWords: [
                VocabularyWord(id: "u1", term: "Zest", meaningVi: "sự hăng hái", source: .user)
            ]
        )
    }

    @Test("addWord stores a normalized user word with the given id")
    func addWord() throws {
        var library = makeLibrary()
        let draft = WordDraft(term: "  serendipity ", partOfSpeech: " ", meaningVi: "sự  tình cờ\nmay mắn")
        let word = try library.addWord(draft, id: "u2")

        #expect(word == VocabularyWord(id: "u2", term: "serendipity", meaningVi: "sự tình cờ may mắn", source: .user))
        #expect(library.userWords.last == word)
        #expect(library.builtInWords.count == 2)
    }

    @Test("addWord rejects invalid drafts without changing the library")
    func addInvalidWord() {
        var library = makeLibrary()
        let before = library
        #expect(throws: WordLibraryError.invalid([.duplicateTerm])) {
            try library.addWord(WordDraft(term: "CALM", meaningVi: "x"))
        }
        #expect(library == before)
    }

    @Test("updateWord keeps the id and replaces the content")
    func updateWord() throws {
        var library = makeLibrary()
        let updated = try library.updateWord(id: "u1", with: WordDraft(term: "zest", meaningVi: "niềm say mê"))
        #expect(updated.id == "u1")
        #expect(library.word(id: "u1")?.meaningVi == "niềm say mê")
    }

    @Test("Built-in words are read-only; unknown ids are reported")
    func readOnlyAndMissing() {
        var library = makeLibrary()
        #expect(throws: WordLibraryError.readOnly) {
            try library.updateWord(id: "b:calm", with: WordDraft(term: "calmer", meaningVi: "x"))
        }
        #expect(throws: WordLibraryError.readOnly) { try library.deleteWord(id: "b:calm") }
        #expect(throws: WordLibraryError.notFound) { try library.deleteWord(id: "missing") }
    }

    @Test("deleteWord removes only that user word")
    func deleteWord() throws {
        var library = makeLibrary()
        try library.deleteWord(id: "u1")
        #expect(library.userWords.isEmpty)
        #expect(library.builtInWords.count == 2)
    }

    @Test("Search matches term or meaning ignoring case and diacritics, sorted by term")
    func search() {
        let library = makeLibrary()
        #expect(library.search("", in: .all).map(\.id) == ["b:ability", "b:calm", "u1"])
        #expect(library.search("CAL", in: .all).map(\.id) == ["b:calm"])
        #expect(library.search("kha nang", in: .all).map(\.id) == ["b:ability"])
        #expect(library.search("", in: .user).map(\.id) == ["u1"])
        #expect(library.search("calm", in: .user).isEmpty)
    }
}
