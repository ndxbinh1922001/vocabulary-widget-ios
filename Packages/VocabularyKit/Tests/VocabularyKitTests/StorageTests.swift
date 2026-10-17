import Foundation
import Testing

@testable import VocabularyKit

@Suite("VocabularyStorage")
struct StorageTests {
    private let userWords = [
        VocabularyWord(id: "u1", term: "zest", meaningVi: "sự hăng hái", source: .user),
        VocabularyWord(id: "u2", term: "glimpse", ipa: "/ɡlɪmps/", meaningVi: "cái nhìn thoáng qua", source: .user),
    ]

    @Test("A missing word file loads as an empty list without an issue")
    func missingWordFile() throws {
        try withTemporaryDirectory { directory in
            let result = VocabularyStorage(directory: directory).loadUserWords(corruptFilePolicy: .moveAside)
            #expect(result.value.isEmpty)
            #expect(result.issue == nil)
        }
    }

    @Test("Saved words load back unchanged inside a versioned envelope")
    func wordRoundTrip() throws {
        try withTemporaryDirectory { directory in
            let storage = VocabularyStorage(directory: directory)
            try storage.saveUserWords(userWords)

            let result = storage.loadUserWords(corruptFilePolicy: .moveAside)
            #expect(result.value == userWords)
            #expect(result.issue == nil)

            let json = try JSONSerialization.jsonObject(with: Data(contentsOf: storage.userWordsURL))
            let object = try #require(json as? [String: Any])
            #expect(object["version"] as? Int == 1)
        }
    }

    @Test("Saving creates the directory when needed")
    func createsDirectory() throws {
        try withTemporaryDirectory { directory in
            let nested = directory.appendingPathComponent("a/b", isDirectory: true)
            try VocabularyStorage(directory: nested).saveUserWords(userWords)
            #expect(FileManager.default.fileExists(atPath: nested.appendingPathComponent("user_words.json").path))
        }
    }

    @Test("Stored words are always reported as user words")
    func sourceIsForcedToUser() throws {
        try withTemporaryDirectory { directory in
            let storage = VocabularyStorage(directory: directory)
            try storage.saveUserWords([VocabularyWord(id: "x", term: "x", meaningVi: "x", source: .builtIn)])
            #expect(storage.loadUserWords(corruptFilePolicy: .moveAside).value.first?.source == .user)
        }
    }

    @Test("A corrupt word file is moved aside byte-for-byte and the app can save again")
    func corruptFileMovedAside() throws {
        try withTemporaryDirectory { directory in
            let storage = VocabularyStorage(directory: directory)
            let garbage = Data("{ not json".utf8)
            try garbage.write(to: storage.userWordsURL)

            let now = Date(timeIntervalSince1970: 1_792_000_000)
            let result = storage.loadUserWords(corruptFilePolicy: .moveAside, now: now)
            #expect(result.value.isEmpty)

            guard case .corruptFile(let name, let backupURL)? = result.issue else {
                Issue.record("Expected a corrupt-file issue, got \(String(describing: result.issue))")
                return
            }
            #expect(name == "user_words.json")
            let backup = try #require(backupURL)
            #expect(backup.lastPathComponent.hasPrefix("user_words.corrupt-"))
            #expect(try Data(contentsOf: backup) == garbage)
            #expect(!FileManager.default.fileExists(atPath: storage.userWordsURL.path))

            try storage.saveUserWords(userWords)
            #expect(storage.loadUserWords(corruptFilePolicy: .moveAside).value == userWords)
        }
    }

    @Test("Backups never overwrite each other")
    func backupNamesAreUnique() throws {
        try withTemporaryDirectory { directory in
            let storage = VocabularyStorage(directory: directory)
            let now = Date(timeIntervalSince1970: 1_792_000_000)
            var backups: [URL] = []
            for index in 0..<2 {
                try Data("broken \(index)".utf8).write(to: storage.userWordsURL)
                if case .corruptFile(_, let backup?)? = storage.loadUserWords(corruptFilePolicy: .moveAside, now: now)
                    .issue
                {
                    backups.append(backup)
                }
            }
            #expect(backups.count == 2)
            #expect(Set(backups).count == 2)
            #expect(try Data(contentsOf: backups[0]) == Data("broken 0".utf8))
            #expect(try Data(contentsOf: backups[1]) == Data("broken 1".utf8))
        }
    }

    @Test("The widget's read-only policy leaves a corrupt file untouched and saving refuses to overwrite it")
    func corruptFileLeftInPlace() throws {
        try withTemporaryDirectory { directory in
            let storage = VocabularyStorage(directory: directory)
            let garbage = Data("[1, 2".utf8)
            try garbage.write(to: storage.userWordsURL)

            let result = storage.loadUserWords(corruptFilePolicy: .leaveInPlace)
            #expect(result.value.isEmpty)
            #expect(result.issue == .corruptFile(name: "user_words.json", backupURL: nil))
            #expect(try Data(contentsOf: storage.userWordsURL) == garbage)

            #expect(throws: StorageError.refusingToOverwriteUnreadableFile(name: "user_words.json")) {
                try storage.saveUserWords(userWords)
            }
            #expect(try Data(contentsOf: storage.userWordsURL) == garbage)
        }
    }

    @Test("An unknown file version is treated as corrupt rather than misread")
    func unsupportedVersion() throws {
        try withTemporaryDirectory { directory in
            let storage = VocabularyStorage(directory: directory)
            try Data(#"{"version": 2, "words": []}"#.utf8).write(to: storage.userWordsURL)
            let result = storage.loadUserWords(corruptFilePolicy: .leaveInPlace)
            #expect(result.issue == .corruptFile(name: "user_words.json", backupURL: nil))
        }
    }

    @Test("Settings default when missing and round-trip when saved")
    func settingsRoundTrip() throws {
        try withTemporaryDirectory { directory in
            let storage = VocabularyStorage(directory: directory)
            let missing = storage.loadSettings()
            #expect(missing.value == .default)
            #expect(missing.issue == nil)

            let custom = RotationSettings(interval: .minutes15, sourceFilter: .user)
            try storage.saveSettings(custom)
            #expect(storage.loadSettings().value == custom)
            #expect(storage.loadSettings().issue == nil)
        }
    }

    @Test(
        "Undecodable settings fall back to defaults",
        arguments: ["garbage", #"{"version":1,"interval":"25h","sourceFilter":"all"}"#])
    func corruptSettings(contents: String) throws {
        try withTemporaryDirectory { directory in
            let storage = VocabularyStorage(directory: directory)
            try Data(contents.utf8).write(to: storage.settingsURL)
            let result = storage.loadSettings()
            #expect(result.value == .default)
            #expect(result.issue == .corruptFile(name: "settings.json", backupURL: nil))
        }
    }
}

@Suite("StorageLocator")
struct StorageLocatorTests {
    @Test(
        "App Group id is read from Info.plist and unexpanded values are rejected",
        arguments: [
            ("group.com.example.vocab", "group.com.example.vocab"),
            ("  group.com.example.vocab \n", "group.com.example.vocab"),
            ("", nil),
            ("$(APP_GROUP_ID)", nil),
        ] as [(String, String?)]
    )
    func appGroupIdentifier(raw: String, expected: String?) {
        #expect(StorageLocator.appGroupIdentifier(infoDictionary: ["AppGroupID": raw]) == expected)
    }

    @Test("Missing Info.plist entries yield no identifier")
    func missingIdentifier() {
        #expect(StorageLocator.appGroupIdentifier(infoDictionary: nil) == nil)
        #expect(StorageLocator.appGroupIdentifier(infoDictionary: ["Other": "x"]) == nil)
    }

    @Test("Location prefers the App Group, then the app-private fallback")
    func locate() {
        let group = URL(fileURLWithPath: "/tmp/group")
        let fallback = URL(fileURLWithPath: "/tmp/fallback")

        #expect(
            StorageLocator.locate(appGroupID: "g", containerURL: { _ in group }, fallbackDirectory: fallback)
                == .appGroup(group.appendingPathComponent("Library/Application Support/VocabWidget", isDirectory: true))
        )
        #expect(
            StorageLocator.locate(appGroupID: "g", containerURL: { _ in nil }, fallbackDirectory: fallback)
                == .appPrivate(fallback))
        #expect(
            StorageLocator.locate(appGroupID: "g", containerURL: { _ in nil }, fallbackDirectory: nil) == .unavailable)
        #expect(
            StorageLocator.locate(appGroupID: nil, containerURL: { _ in group }, fallbackDirectory: nil) == .unavailable
        )
    }

    @Test("Only the App Group location is shared with the widget")
    func isShared() {
        let url = URL(fileURLWithPath: "/tmp/x")
        #expect(StorageLocation.appGroup(url).isShared)
        #expect(!StorageLocation.appPrivate(url).isShared)
        #expect(StorageLocation.unavailable.directory == nil)
    }
}

@Suite("LegacyStorageMigration")
struct LegacyStorageMigrationTests {
    /// Creates `<root>/Library/Application Support/VocabWidget` like the App Group layout.
    private func layout(_ root: URL) -> (legacy: URL, current: URL) {
        (root, StorageLocator.appGroupDataDirectory(inContainer: root))
    }

    @Test("Version 1.0 files at the container root are moved into the data folder byte-for-byte")
    func movesLegacyFiles() throws {
        try withTemporaryDirectory { root in
            let (legacy, current) = layout(root)
            let words = Data(#"{"version":1,"words":[]}"#.utf8)
            let settings = Data(#"{"version":1,"interval":"15m","sourceFilter":"user"}"#.utf8)
            try words.write(to: legacy.appendingPathComponent("user_words.json"))
            try settings.write(to: legacy.appendingPathComponent("settings.json"))

            let moved = LegacyStorageMigration.migrate(from: legacy, to: current)

            #expect(moved == ["user_words.json", "settings.json"])
            #expect(try Data(contentsOf: current.appendingPathComponent("user_words.json")) == words)
            #expect(try Data(contentsOf: current.appendingPathComponent("settings.json")) == settings)
            #expect(!FileManager.default.fileExists(atPath: legacy.appendingPathComponent("user_words.json").path))
            #expect(VocabularyStorage(directory: current).loadSettings().value.interval == .minutes15)
        }
    }

    @Test("Existing files in the data folder are never overwritten and the legacy copy is kept")
    func neverOverwrites() throws {
        try withTemporaryDirectory { root in
            let (legacy, current) = layout(root)
            try FileManager.default.createDirectory(at: current, withIntermediateDirectories: true)
            let newer = Data("newer".utf8)
            let older = Data("older".utf8)
            try newer.write(to: current.appendingPathComponent("user_words.json"))
            try older.write(to: legacy.appendingPathComponent("user_words.json"))

            #expect(LegacyStorageMigration.migrate(from: legacy, to: current).isEmpty)
            #expect(try Data(contentsOf: current.appendingPathComponent("user_words.json")) == newer)
            #expect(try Data(contentsOf: legacy.appendingPathComponent("user_words.json")) == older)
        }
    }

    @Test("Nothing to migrate is a no-op that creates nothing")
    func noLegacyFiles() throws {
        try withTemporaryDirectory { root in
            let (legacy, current) = layout(root)
            #expect(LegacyStorageMigration.migrate(from: legacy, to: current).isEmpty)
            #expect(!FileManager.default.fileExists(atPath: current.path))
            #expect(LegacyStorageMigration.migrate(from: current, to: current).isEmpty)
        }
    }

    private let sampleWords = [VocabularyWord(id: "u1", term: "zest", meaningVi: "sự hăng hái", source: .user)]

    @Test("Partial migration: words still at the legacy root stay visible and saves go back there (Codex case)")
    func partialMigrationKeepsLegacyWords() throws {
        try withTemporaryDirectory { root in
            let (legacy, current) = layout(root)
            try FileManager.default.createDirectory(at: current, withIntermediateDirectories: true)
            try VocabularyStorage(directory: legacy).saveUserWords(sampleWords)
            try VocabularyStorage(directory: current).saveSettings(
                RotationSettings(interval: .minutes15, sourceFilter: .user))

            let storage = LegacyStorageMigration.resolvedStorage(preferred: current, legacy: legacy)
            #expect(storage.loadUserWords(corruptFilePolicy: .leaveInPlace).value == sampleWords)
            #expect(storage.loadSettings().value.interval == .minutes15)

            // Saving writes to where the words live, so nothing is orphaned at the old location.
            let updated =
                sampleWords + [
                    VocabularyWord(id: "u2", term: "glimpse", meaningVi: "cái nhìn thoáng qua", source: .user)
                ]
            try storage.saveUserWords(updated)
            #expect(!FileManager.default.fileExists(atPath: current.appendingPathComponent("user_words.json").path))
            #expect(
                VocabularyStorage(directory: legacy).loadUserWords(corruptFilePolicy: .leaveInPlace).value == updated)

            // A later successful migration moves the up-to-date file.
            #expect(LegacyStorageMigration.migrate(from: legacy, to: current) == ["user_words.json"])
            let after = LegacyStorageMigration.resolvedStorage(preferred: current, legacy: legacy)
            #expect(after.loadUserWords(corruptFilePolicy: .leaveInPlace).value == updated)
        }
    }

    @Test("Settings-only version 1.0 data is honoured before the app migrates it (Antigravity case)")
    func settingsOnlyLegacy() throws {
        try withTemporaryDirectory { root in
            let (legacy, current) = layout(root)
            try VocabularyStorage(directory: legacy).saveSettings(
                RotationSettings(interval: .minutes30, sourceFilter: .builtIn))

            let storage = LegacyStorageMigration.resolvedStorage(preferred: current, legacy: legacy)
            #expect(storage.loadSettings().value == RotationSettings(interval: .minutes30, sourceFilter: .builtIn))
            #expect(storage.loadUserWords(corruptFilePolicy: .leaveInPlace).value.isEmpty)
            #expect(storage.userWordsURL.deletingLastPathComponent().standardizedFileURL == current.standardizedFileURL)
        }
    }

    @Test("A move that fails leaves the file readable at the legacy location")
    func failedMoveStaysReadable() throws {
        try withTemporaryDirectory { root in
            let (legacy, current) = layout(root)
            try VocabularyStorage(directory: legacy).saveUserWords(sampleWords)
            // A plain file where the data folder should be makes createDirectory fail.
            try FileManager.default.createDirectory(
                at: current.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: current)

            #expect(LegacyStorageMigration.migrate(from: legacy, to: current).isEmpty)
            let storage = LegacyStorageMigration.resolvedStorage(preferred: current, legacy: legacy)
            #expect(storage.loadUserWords(corruptFilePolicy: .leaveInPlace).value == sampleWords)
        }
    }

    @Test("Fresh installs and missing legacy folders use the new location")
    func freshInstall() throws {
        try withTemporaryDirectory { root in
            let (legacy, current) = layout(root)
            for candidate in [legacy, nil] as [URL?] {
                let storage = LegacyStorageMigration.resolvedStorage(preferred: current, legacy: candidate)
                #expect(storage.userWordsURL == current.appendingPathComponent("user_words.json"))
                #expect(storage.settingsURL == current.appendingPathComponent("settings.json"))
            }
        }
    }

    @Test("Files present in both locations are reported; the new copy wins")
    func conflicts() throws {
        try withTemporaryDirectory { root in
            let (legacy, current) = layout(root)
            #expect(LegacyStorageMigration.conflictingFiles(preferred: current, legacy: legacy).isEmpty)
            try VocabularyStorage(directory: legacy).saveUserWords(sampleWords)
            try VocabularyStorage(directory: current).saveUserWords([])
            #expect(LegacyStorageMigration.conflictingFiles(preferred: current, legacy: legacy) == ["user_words.json"])
            let storage = LegacyStorageMigration.resolvedStorage(preferred: current, legacy: legacy)
            #expect(storage.loadUserWords(corruptFilePolicy: .leaveInPlace).value.isEmpty)
        }
    }
}
