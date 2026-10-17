import Foundation
import Testing
import VocabularyKit

@testable import VocabWidget

/// iOS-only checks that cannot run in the macOS package tests: resources inside the app bundle,
/// build-setting expansion in Info.plist, and how `AppModel` behaves without an App Group.
@Suite("App bundle integration")
struct BundleIntegrationTests {
    @Test("Built-in words load from inside the iOS app bundle")
    func builtInWordsLoad() {
        #expect(BuiltInVocabulary.load().count >= 100)
    }

    @Test("Info.plist exposes the expanded App Group id")
    func appGroupIdentifierIsExpanded() throws {
        let identifier = try #require(StorageLocator.appGroupIdentifier(infoDictionary: Bundle.main.infoDictionary))
        #expect(identifier.hasPrefix("group."))
    }

    @MainActor
    @Test("Without an App Group, words are saved privately and the widget limitation is reported")
    func appPrivateFallback() throws {
        try withTemporaryDirectory { directory in
            let reloads = ReloadCounter()
            let model = AppModel(
                location: .appPrivate(directory), builtInWords: BuiltInVocabulary.load(),
                reloadWidgets: reloads.increment)
            #expect(model.notices.contains(.widgetCannotSeeUserWords))

            try model.addWord(WordDraft(term: "zest", meaningVi: "sự hăng hái"))
            #expect(reloads.count == 1)

            let reopened = AppModel(location: .appPrivate(directory), builtInWords: [], reloadWidgets: {})
            #expect(reopened.library.userWords.map(\.term) == ["zest"])
        }
    }

    @MainActor
    @Test("Unavailable storage rejects changes and leaves state untouched")
    func unavailableStorage() {
        let reloads = ReloadCounter()
        let model = AppModel(location: .unavailable, builtInWords: [], reloadWidgets: reloads.increment)
        #expect(model.notices.contains(.storageUnavailable))
        #expect(throws: AppModelError.saveFailed) {
            try model.addWord(WordDraft(term: "zest", meaningVi: "sự hăng hái"))
        }
        #expect(model.library.userWords.isEmpty)
        #expect(reloads.count == 0)
    }

    @MainActor
    @Test("A corrupt word file is preserved and reported with its backup name")
    func corruptWordFile() throws {
        try withTemporaryDirectory { directory in
            try Data("{ broken".utf8).write(to: directory.appendingPathComponent(VocabularyStorage.userWordsFileName))
            let model = AppModel(location: .appGroup(directory), builtInWords: [], reloadWidgets: {})
            let backupName = model.notices.lazy.compactMap { notice -> String? in
                if case .corruptWordsFileMovedAside(let name) = notice { return name }
                return nil
            }.first
            #expect(backupName?.hasPrefix("user_words.corrupt-") == true)
            #expect(!model.notices.contains(.wordsFileUnreadable))
        }
    }

    @MainActor
    @Test("Settings changes persist and reload widgets once per change")
    func settingsPersist() throws {
        try withTemporaryDirectory { directory in
            let reloads = ReloadCounter()
            let model = AppModel(location: .appGroup(directory), builtInWords: [], reloadWidgets: reloads.increment)
            try model.setInterval(.minutes15)
            try model.setInterval(.minutes15)
            try model.setSourceFilter(.user)
            #expect(reloads.count == 2)

            let reopened = AppModel(location: .appGroup(directory), builtInWords: [], reloadWidgets: {})
            #expect(reopened.settings == RotationSettings(interval: .minutes15, sourceFilter: .user))
        }
    }

    @MainActor
    @Test("Out-of-range intervals are rejected and custom ones persist")
    func customInterval() throws {
        try withTemporaryDirectory { directory in
            let reloads = ReloadCounter()
            let model = AppModel(location: .appGroup(directory), builtInWords: [], reloadWidgets: reloads.increment)
            #expect(throws: AppModelError.invalidInterval) {
                try model.setInterval(.every(amount: 10, unit: .seconds))
            }
            #expect(model.settings.interval == .hour1)
            #expect(reloads.count == 0)

            try model.setInterval(.every(amount: 45, unit: .seconds))
            let reopened = AppModel(location: .appGroup(directory), builtInWords: [], reloadWidgets: {})
            #expect(reopened.settings.interval == .every(amount: 45, unit: .seconds))
        }
    }

    @MainActor
    @Test("With resolved storage the app keeps using words still at the version 1.0 location")
    func legacyWordsStayWritable() throws {
        try withTemporaryDirectory { root in
            let current = StorageLocator.appGroupDataDirectory(inContainer: root)
            try VocabularyStorage(directory: root).saveUserWords([
                VocabularyWord(id: "u1", term: "zest", meaningVi: "sự hăng hái", source: .user)
            ])
            let model = AppModel(
                location: .appGroup(current),
                storage: LegacyStorageMigration.resolvedStorage(preferred: current, legacy: root),
                builtInWords: [],
                additionalNotices: [.legacyFilesKept(["user_words.json"])],
                reloadWidgets: {}
            )
            #expect(model.library.userWords.map(\.term) == ["zest"])
            #expect(model.notices.contains(.legacyFilesKept(["user_words.json"])))

            try model.addWord(WordDraft(term: "glimpse", meaningVi: "cái nhìn thoáng qua"))
            let legacyWords = VocabularyStorage(directory: root).loadUserWords(corruptFilePolicy: .leaveInPlace).value
            #expect(legacyWords.map(\.term) == ["zest", "glimpse"])
            #expect(!FileManager.default.fileExists(atPath: current.appendingPathComponent("user_words.json").path))
        }
    }
}

@MainActor
private final class ReloadCounter {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}

private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("VocabWidgetTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: url) }
    try body(url)
}
