import Foundation
import os

/// Moves shared files from the version 1.0 location (the App Group container root) into the
/// current data folder (`StorageLocator.appGroupDataSubpath`).
///
/// Every file is handled on its own: a file lives in the new folder once it exists there, and in
/// the legacy folder until then. The app (single writer) runs `migrate`, then both the app and the
/// read-only widget open `resolvedStorage`, so a partially failed migration never hides a file and
/// the app keeps saving to wherever each file currently is.
public enum LegacyStorageMigration {
    /// Files that are migrated. Corrupt-file backups stay where they are.
    public static let fileNames = [VocabularyStorage.userWordsFileName, VocabularyStorage.settingsFileName]

    private static let logger = Logger(subsystem: "VocabularyKit", category: "LegacyStorageMigration")

    /// Moves each file from `legacyDirectory` into `directory` when only the legacy copy exists.
    /// A file that already exists in `directory` is never overwritten; its legacy copy is left untouched
    /// (see `conflictingFiles`). A failed move leaves the legacy file in place for the next launch.
    ///
    /// - Returns: The names of the files that were moved.
    @discardableResult
    public static func migrate(from legacyDirectory: URL, to directory: URL) -> [String] {
        guard legacyDirectory.standardizedFileURL != directory.standardizedFileURL else { return [] }
        let fileManager = FileManager.default
        var moved: [String] = []
        for name in fileNames {
            let source = legacyDirectory.appendingPathComponent(name)
            let destination = directory.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: source.path), !fileManager.fileExists(atPath: destination.path) else {
                continue
            }
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                try fileManager.moveItem(at: source, to: destination)
                moved.append(name)
            } catch {
                logger.error("Moving \(name, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            }
        }
        return moved
    }

    /// Storage whose files each point at where that file currently lives: `directory` if the file
    /// exists there, otherwise `legacyDirectory` if it still holds the file, otherwise `directory`.
    public static func resolvedStorage(preferred directory: URL, legacy legacyDirectory: URL?) -> VocabularyStorage {
        VocabularyStorage(
            userWordsDirectory: location(
                of: VocabularyStorage.userWordsFileName, preferred: directory, legacy: legacyDirectory),
            settingsDirectory: location(
                of: VocabularyStorage.settingsFileName, preferred: directory, legacy: legacyDirectory)
        )
    }

    /// Files present in both folders. The new copy wins and the legacy copy is kept, never deleted;
    /// the app reports these so the older data is not silently ignored.
    public static func conflictingFiles(preferred directory: URL, legacy legacyDirectory: URL) -> [String] {
        guard legacyDirectory.standardizedFileURL != directory.standardizedFileURL else { return [] }
        let fileManager = FileManager.default
        return fileNames.filter { name in
            fileManager.fileExists(atPath: directory.appendingPathComponent(name).path)
                && fileManager.fileExists(atPath: legacyDirectory.appendingPathComponent(name).path)
        }
    }

    private static func location(of name: String, preferred directory: URL, legacy legacyDirectory: URL?) -> URL {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: directory.appendingPathComponent(name).path) {
            return directory
        }
        if let legacyDirectory, fileManager.fileExists(atPath: legacyDirectory.appendingPathComponent(name).path) {
            return legacyDirectory
        }
        return directory
    }
}
