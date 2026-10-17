import Combine
import SwiftUI
import VocabularyKit
import WidgetKit

@main
struct VocabWidgetApp: App {
    @State private var model: AppModel

    init() {
        let location = StorageLocator.current(allowAppPrivateFallback: true)
        var storage: VocabularyStorage?
        var notices: [AppNotice] = []
        // Version 1.0 kept its files at the App Group root. Move them before the first load, then
        // follow each file to wherever it is, so a move that failed keeps working at the old place.
        if case .appGroup(let directory) = location, let container = StorageLocator.currentAppGroupContainer() {
            LegacyStorageMigration.migrate(from: container, to: directory)
            storage = LegacyStorageMigration.resolvedStorage(preferred: directory, legacy: container)
            let kept = LegacyStorageMigration.conflictingFiles(preferred: directory, legacy: container)
            if !kept.isEmpty {
                notices.append(.legacyFilesKept(kept))
            }
        }
        _model = State(
            initialValue: AppModel(
                location: location,
                storage: storage,
                builtInWords: BuiltInVocabulary.load(),
                additionalNotices: notices,
                reloadWidgets: { WidgetCenter.shared.reloadAllTimelines() }
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                // The posting thread of this notification is unspecified; hop to the main queue
                // because the handler mutates MainActor-isolated state.
                .onReceive(
                    NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)
                        .receive(on: DispatchQueue.main)
                ) { _ in
                    model.systemTimeZoneDidChange()
                }
        }
    }
}
