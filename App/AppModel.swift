import Foundation
import Observation
import VocabularyKit
import os

/// A persistent condition the user should know about, shown as a banner.
nonisolated enum AppNotice: Equatable, Identifiable {
    /// Words are saved in an app-private folder, so the widget only shows built-in words.
    case widgetCannotSeeUserWords
    /// No folder could be found to save words at all.
    case storageUnavailable
    /// The word file was corrupt and has been preserved under `backupName`.
    case corruptWordsFileMovedAside(backupName: String)
    /// The word file could not be read or moved; saving is blocked to protect it.
    case wordsFileUnreadable
    /// Settings could not be read and were reset to defaults.
    case settingsReset
    /// The bundled word list is missing from the app.
    case builtInWordsMissing
    /// Version 1.0 files were kept at the old location because the new one already had them.
    case legacyFilesKept([String])

    var id: String {
        switch self {
        case .widgetCannotSeeUserWords: "widget"
        case .storageUnavailable: "storage"
        case .corruptWordsFileMovedAside(let name): "corrupt-\(name)"
        case .wordsFileUnreadable: "unreadable"
        case .settingsReset: "settings"
        case .builtInWordsMissing: "builtin"
        case .legacyFilesKept: "legacy"
        }
    }

    var message: String {
        switch self {
        case .widgetCannotSeeUserWords:
            "Widget chưa đọc được từ của bạn (thiếu App Group). Widget tạm hiển thị bộ từ có sẵn."
        case .storageUnavailable:
            "Không tìm thấy nơi lưu dữ liệu. Thay đổi sẽ không được lưu."
        case .corruptWordsFileMovedAside(let name):
            "File từ của bạn bị lỗi nên đã được giữ lại thành \(name). Danh sách bắt đầu lại từ đầu."
        case .wordsFileUnreadable:
            "Không đọc được file từ của bạn. Tạm thời không thể lưu để tránh mất dữ liệu."
        case .settingsReset:
            "Không đọc được cài đặt, đã dùng cài đặt mặc định."
        case .builtInWordsMissing:
            "Không tải được bộ từ có sẵn."
        case .legacyFilesKept(let names):
            "Có dữ liệu cũ (\(names.joined(separator: ", "))) chưa chuyển được vì vị trí mới đã có bản khác. Bản cũ vẫn được giữ nguyên."
        }
    }
}

nonisolated enum AppModelError: Error, Equatable {
    case invalid([WordValidationIssue])
    case readOnly
    case notFound
    case saveFailed
    case invalidInterval

    var message: String {
        switch self {
        case .invalid: "Vui lòng kiểm tra lại các trường bị lỗi."
        case .readOnly: "Từ có sẵn không thể sửa hoặc xóa."
        case .notFound: "Không tìm thấy từ này."
        case .saveFailed: "Không lưu được thay đổi. Vui lòng thử lại."
        case .invalidInterval: "Chu kỳ phải từ \(RotationInterval.minimumSeconds) giây đến 24 giờ."
        }
    }
}

/// App state: the word library and settings, persisted through `VocabularyStorage`.
///
/// Every mutation is applied to a copy, persisted, and only then published, so a failed
/// save never leaves the UI showing data that is not on disk.
@Observable
final class AppModel {
    private(set) var library: WordLibrary
    private(set) var settings: RotationSettings
    private(set) var notices: [AppNotice]
    /// Time zone used for rotation; refreshed when the system time zone changes.
    private(set) var timeZone: TimeZone

    let location: StorageLocation
    private let storage: VocabularyStorage?
    private let reloadWidgets: @MainActor () -> Void
    private static let logger = Logger(subsystem: "VocabWidget", category: "AppModel")

    init(
        location: StorageLocation,
        storage: VocabularyStorage? = nil,
        builtInWords: [VocabularyWord],
        additionalNotices: [AppNotice] = [],
        timeZone: TimeZone = .current,
        reloadWidgets: @escaping @MainActor () -> Void
    ) {
        self.location = location
        self.timeZone = timeZone
        self.reloadWidgets = reloadWidgets
        // An explicit storage lets the app follow files that are still at their version 1.0 location.
        self.storage = storage ?? location.directory.map(VocabularyStorage.init(directory:))

        var notices: [AppNotice] = []
        switch location {
        case .appGroup: break
        case .appPrivate: notices.append(.widgetCannotSeeUserWords)
        case .unavailable: notices.append(.storageUnavailable)
        }
        if builtInWords.isEmpty {
            notices.append(.builtInWordsMissing)
        }
        notices += additionalNotices

        var userWords: [VocabularyWord] = []
        var settings = RotationSettings.default
        if let storage = self.storage {
            let wordsResult = storage.loadUserWords(corruptFilePolicy: .moveAside)
            userWords = wordsResult.value
            switch wordsResult.issue {
            case .corruptFile(_, let backupURL?)?:
                notices.append(.corruptWordsFileMovedAside(backupName: backupURL.lastPathComponent))
            case .corruptFile(_, nil)?, .unreadable?:
                notices.append(.wordsFileUnreadable)
            case nil:
                break
            }

            let settingsResult = storage.loadSettings()
            settings = settingsResult.value
            if settingsResult.issue != nil {
                notices.append(.settingsReset)
            }
        }

        library = WordLibrary(builtInWords: builtInWords, userWords: userWords)
        self.settings = settings
        self.notices = notices
    }

    // MARK: Rotation

    var rotation: WordRotation {
        WordRotation(words: library.words(in: settings.sourceFilter), interval: settings.interval, timeZone: timeZone)
    }

    func currentWord(at date: Date) -> VocabularyWord? {
        rotation.word(at: date)
    }

    func upcomingWords(after date: Date, count: Int) -> [ScheduledWord] {
        rotation.upcoming(after: date, count: count)
    }

    func systemTimeZoneDidChange() {
        NSTimeZone.resetSystemTimeZone()
        timeZone = .current
        reloadWidgets()
    }

    // MARK: Words

    func addWord(_ draft: WordDraft) throws(AppModelError) {
        var updated = library
        do throws(WordLibraryError) {
            try updated.addWord(draft)
        } catch {
            throw Self.map(error)
        }
        try commitUserWords(updated)
    }

    func updateWord(id: String, with draft: WordDraft) throws(AppModelError) {
        var updated = library
        do throws(WordLibraryError) {
            try updated.updateWord(id: id, with: draft)
        } catch {
            throw Self.map(error)
        }
        try commitUserWords(updated)
    }

    func deleteWord(id: String) throws(AppModelError) {
        var updated = library
        do throws(WordLibraryError) {
            try updated.deleteWord(id: id)
        } catch {
            throw Self.map(error)
        }
        try commitUserWords(updated)
    }

    // MARK: Settings

    func setInterval(_ interval: RotationInterval) throws(AppModelError) {
        guard interval.isValid else { throw .invalidInterval }
        var updated = settings
        updated.interval = interval
        try commitSettings(updated)
    }

    func setSourceFilter(_ filter: WordSourceFilter) throws(AppModelError) {
        var updated = settings
        updated.sourceFilter = filter
        try commitSettings(updated)
    }

    // MARK: Persistence

    private func commitUserWords(_ updated: WordLibrary) throws(AppModelError) {
        guard let storage else { throw .saveFailed }
        do {
            try storage.saveUserWords(updated.userWords)
        } catch {
            Self.logger.error("Saving user words failed: \(String(describing: error), privacy: .public)")
            throw .saveFailed
        }
        library = updated
        reloadWidgets()
    }

    private func commitSettings(_ updated: RotationSettings) throws(AppModelError) {
        guard updated != settings else { return }
        guard let storage else { throw .saveFailed }
        do {
            try storage.saveSettings(updated)
        } catch {
            Self.logger.error("Saving settings failed: \(String(describing: error), privacy: .public)")
            throw .saveFailed
        }
        settings = updated
        notices.removeAll { $0 == .settingsReset }
        reloadWidgets()
    }

    private static func map(_ error: WordLibraryError) -> AppModelError {
        switch error {
        case .invalid(let issues): .invalid(issues)
        case .readOnly: .readOnly
        case .notFound: .notFound
        }
    }
}
