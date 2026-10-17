import Foundation
import os

/// A problem found while reading shared data. Loading never throws: callers always get a usable value
/// plus, at most, one issue to surface in the UI.
public enum StorageIssue: Equatable, Sendable {
    /// The file could not be decoded. `backupURL` is where it was moved, or `nil` when it was left in place.
    case corruptFile(name: String, backupURL: URL?)
    /// The file exists but could not be read (permissions, I/O).
    case unreadable(name: String, description: String)
}

public enum StorageError: Error, Equatable, Sendable {
    /// A word file exists that cannot be decoded; writing would destroy it.
    case refusingToOverwriteUnreadableFile(name: String)
}

public struct LoadResult<Value: Sendable>: Sendable {
    public let value: Value
    public let issue: StorageIssue?

    public init(value: Value, issue: StorageIssue?) {
        self.value = value
        self.issue = issue
    }
}

/// What to do with a word file that cannot be decoded.
public enum CorruptFilePolicy: Sendable {
    /// Leave it untouched. Used by the widget, which must never write.
    case leaveInPlace
    /// Rename it to `user_words.corrupt-<timestamp>.json` so it is preserved and the app can keep working.
    case moveAside
}

/// File-based persistence for the shared files (normally one folder in the App Group container).
///
/// The app is the only writer; every write is atomic, so the widget never observes a half-written file.
public struct VocabularyStorage: Sendable {
    public static let userWordsFileName = "user_words.json"
    public static let settingsFileName = "settings.json"
    public static let currentVersion = 1

    private static let logger = Logger(subsystem: "VocabularyKit", category: "Storage")

    public let userWordsURL: URL
    public let settingsURL: URL

    /// Both files in one folder (the normal case).
    public init(directory: URL) {
        self.init(userWordsDirectory: directory, settingsDirectory: directory)
    }

    /// Each file in its own folder, used while version 1.0 files are migrated one by one
    /// (see `LegacyStorageMigration.resolvedStorage`).
    public init(userWordsDirectory: URL, settingsDirectory: URL) {
        userWordsURL = userWordsDirectory.appendingPathComponent(Self.userWordsFileName)
        settingsURL = settingsDirectory.appendingPathComponent(Self.settingsFileName)
    }

    // MARK: - User words

    private struct UserWordsEnvelope: Codable {
        let version: Int
        let words: [VocabularyWord]
    }

    private struct UnsupportedVersion: Error {
        let version: Int
    }

    /// Loads the user's words. A missing file yields an empty list without an issue.
    public func loadUserWords(corruptFilePolicy: CorruptFilePolicy, now: Date = Date()) -> LoadResult<[VocabularyWord]>
    {
        let url = userWordsURL
        let data: Data
        switch readFile(at: url) {
        case .missing:
            return LoadResult(value: [], issue: nil)
        case .failed(let description):
            return LoadResult(value: [], issue: .unreadable(name: Self.userWordsFileName, description: description))
        case .data(let contents):
            data = contents
        }

        do {
            let words = try decodeUserWords(data)
            return LoadResult(value: words, issue: nil)
        } catch {
            Self.logger.error("Corrupt user word file: \(String(describing: error), privacy: .public)")
            let backupURL = corruptFilePolicy == .moveAside ? moveAside(url, now: now) : nil
            return LoadResult(value: [], issue: .corruptFile(name: Self.userWordsFileName, backupURL: backupURL))
        }
    }

    /// Atomically replaces the user word file.
    ///
    /// Throws `StorageError.refusingToOverwriteUnreadableFile` when an existing file cannot be decoded,
    /// so data that failed to move aside is never silently destroyed.
    public func saveUserWords(_ words: [VocabularyWord]) throws {
        switch readFile(at: userWordsURL) {
        case .missing:
            break
        case .failed:
            throw StorageError.refusingToOverwriteUnreadableFile(name: Self.userWordsFileName)
        case .data(let contents):
            guard (try? decodeUserWords(contents)) != nil else {
                throw StorageError.refusingToOverwriteUnreadableFile(name: Self.userWordsFileName)
            }
        }
        let envelope = UserWordsEnvelope(version: Self.currentVersion, words: words)
        try write(envelope, to: userWordsURL)
    }

    private func decodeUserWords(_ data: Data) throws -> [VocabularyWord] {
        let envelope = try JSONDecoder().decode(UserWordsEnvelope.self, from: data)
        guard envelope.version == Self.currentVersion else {
            throw UnsupportedVersion(version: envelope.version)
        }
        // Everything in this file is a user word, whatever the stored `source` says.
        return envelope.words.map { word in
            var word = word
            word.source = .user
            return word
        }
    }

    // MARK: - Settings

    private struct SettingsEnvelope: Codable {
        let version: Int
        let interval: RotationInterval
        let sourceFilter: WordSourceFilter
    }

    /// Loads settings, falling back to `RotationSettings.default`. Settings are not user content,
    /// so an undecodable file is left in place and replaced by the next save.
    public func loadSettings() -> LoadResult<RotationSettings> {
        switch readFile(at: settingsURL) {
        case .missing:
            return LoadResult(value: .default, issue: nil)
        case .failed(let description):
            return LoadResult(
                value: .default, issue: .unreadable(name: Self.settingsFileName, description: description))
        case .data(let data):
            guard let envelope = try? JSONDecoder().decode(SettingsEnvelope.self, from: data),
                envelope.version == Self.currentVersion
            else {
                return LoadResult(value: .default, issue: .corruptFile(name: Self.settingsFileName, backupURL: nil))
            }
            return LoadResult(
                value: RotationSettings(interval: envelope.interval, sourceFilter: envelope.sourceFilter),
                issue: nil
            )
        }
    }

    public func saveSettings(_ settings: RotationSettings) throws {
        let envelope = SettingsEnvelope(
            version: Self.currentVersion,
            interval: settings.interval,
            sourceFilter: settings.sourceFilter
        )
        try write(envelope, to: settingsURL)
    }

    // MARK: - File helpers

    private enum ReadOutcome {
        case missing
        case data(Data)
        case failed(String)
    }

    private func readFile(at url: URL) -> ReadOutcome {
        guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
        do {
            return .data(try Data(contentsOf: url))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return .missing
        } catch {
            return .failed(String(describing: error))
        }
    }

    private func write(_ value: some Encodable, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url, options: [.atomic])
    }

    /// Renames a corrupt file to `<name>.corrupt-<UTC timestamp>[-n].json`. Returns `nil` if the move failed.
    private func moveAside(_ url: URL, now: Date) -> URL? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withTimeZone]
        let stamp = formatter.string(from: now)
        let baseName = url.deletingPathExtension().lastPathComponent
        let fileManager = FileManager.default

        for attempt in 0..<100 {
            let suffix = attempt == 0 ? "" : "-\(attempt)"
            let candidate = url.deletingLastPathComponent()
                .appendingPathComponent("\(baseName).corrupt-\(stamp)\(suffix).json")
            guard !fileManager.fileExists(atPath: candidate.path) else { continue }
            do {
                try fileManager.moveItem(at: url, to: candidate)
                return candidate
            } catch {
                Self.logger.error("Could not move corrupt file aside: \(String(describing: error), privacy: .public)")
                return nil
            }
        }
        return nil
    }
}
