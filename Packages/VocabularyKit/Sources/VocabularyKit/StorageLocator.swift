import Foundation

/// Where shared data lives for the current process.
public enum StorageLocation: Equatable, Sendable {
    /// The App Group container shared by the app and the widget.
    case appGroup(URL)
    /// App-private fallback used when the App Group is unavailable. The widget cannot see it.
    case appPrivate(URL)
    /// No usable directory could be determined.
    case unavailable

    public var directory: URL? {
        switch self {
        case .appGroup(let url), .appPrivate(let url): url
        case .unavailable: nil
        }
    }

    /// `true` when the widget reads the same files as the app.
    public var isShared: Bool {
        if case .appGroup = self { return true }
        return false
    }
}

public enum StorageLocator {
    /// Info.plist key whose value is expanded from `$(APP_GROUP_ID)` in `Config/Base.xcconfig`.
    public static let appGroupInfoKey = "AppGroupID"

    /// Folder inside the App Group container that holds the shared files. Version 1.0 used the
    /// container root, which `devicectl device copy` cannot write to; see `LegacyStorageMigration`.
    public static let appGroupDataSubpath = "Library/Application Support/VocabWidget"

    /// The shared data directory inside an App Group container.
    public static func appGroupDataDirectory(inContainer container: URL) -> URL {
        container.appendingPathComponent(appGroupDataSubpath, isDirectory: true)
    }

    /// Reads the App Group id from an Info.plist dictionary.
    /// Returns `nil` for missing, empty or unexpanded (`$(...)`) values.
    public static func appGroupIdentifier(infoDictionary: [String: Any]?) -> String? {
        guard let raw = infoDictionary?[appGroupInfoKey] as? String else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains("$(") else { return nil }
        return value
    }

    /// Chooses the storage directory.
    ///
    /// - Parameters:
    ///   - appGroupID: Identifier from Info.plist, if any.
    ///   - containerURL: Resolves an App Group id to its container; returns `nil` when the
    ///     entitlement is missing (for example in unsigned simulator builds).
    ///   - fallbackDirectory: App-private directory, or `nil` for processes that must only read
    ///     shared data (the widget).
    public static func locate(
        appGroupID: String?,
        containerURL: (String) -> URL?,
        fallbackDirectory: URL?
    ) -> StorageLocation {
        if let appGroupID, let container = containerURL(appGroupID) {
            return .appGroup(appGroupDataDirectory(inContainer: container))
        }
        if let fallbackDirectory {
            return .appPrivate(fallbackDirectory)
        }
        return .unavailable
    }

    /// Root of the current process's App Group container, where version 1.0 kept its files.
    /// `nil` when the App Group is unavailable.
    public static func currentAppGroupContainer(bundle: Bundle = .main) -> URL? {
        appGroupIdentifier(infoDictionary: bundle.infoDictionary).flatMap {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)
        }
    }

    /// Production lookup for the current process.
    ///
    /// - Parameter allowAppPrivateFallback: `true` for the app, `false` for the widget.
    public static func current(bundle: Bundle = .main, allowAppPrivateFallback: Bool) -> StorageLocation {
        let fileManager = FileManager.default
        let fallback =
            allowAppPrivateFallback
            ? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("VocabWidget", isDirectory: true)
            : nil
        return locate(
            appGroupID: appGroupIdentifier(infoDictionary: bundle.infoDictionary),
            containerURL: { fileManager.containerURL(forSecurityApplicationGroupIdentifier: $0) },
            fallbackDirectory: fallback
        )
    }
}
