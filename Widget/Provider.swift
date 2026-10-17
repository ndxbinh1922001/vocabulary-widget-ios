import Foundation
import VocabularyKit
import WidgetKit

struct WordEntry: TimelineEntry {
    let date: Date
    /// `nil` renders the "no words" placeholder.
    let word: VocabularyWord?
}

extension WordEntry {
    init(_ entry: TimelinePlan.Entry) {
        self.init(date: entry.date, word: entry.word)
    }

    /// Shown in the widget gallery and while the real timeline loads.
    static let sample = WordEntry(
        date: Date(),
        word: VocabularyWord(
            id: "sample",
            term: "serendipity",
            ipa: "/ˌserənˈdɪpəti/",
            partOfSpeech: "noun",
            meaningVi: "sự tình cờ may mắn",
            example: "Finding this café was pure serendipity.",
            source: .builtIn
        )
    )
}

/// Builds timelines from the shared files. Never writes: the app is the only writer.
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WordEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        if context.isPreview {
            completion(.sample)
            return
        }
        let plan = WidgetDataSource.plan(now: Date())
        completion(plan.entries.first.map(WordEntry.init) ?? .sample)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
        let plan = WidgetDataSource.plan(now: Date())
        let policy: TimelineReloadPolicy =
            switch plan.reloadPolicy {
            case .atEnd: .atEnd
            case .never: .never
            }
        completion(Timeline(entries: plan.entries.map(WordEntry.init), policy: policy))
    }
}

enum WidgetDataSource {
    /// Reads built-in words plus the user's words and settings from the App Group.
    /// Without an App Group (unsigned builds, misconfiguration) it falls back to built-in words.
    static func plan(now: Date) -> TimelinePlan {
        var words = BuiltInVocabulary.load()
        var settings = RotationSettings.default
        if let directory = StorageLocator.current(allowAppPrivateFallback: false).directory {
            // Read each file where it currently is: version 1.0 files stay at the App Group root
            // until the app has moved them.
            let storage = LegacyStorageMigration.resolvedStorage(
                preferred: directory,
                legacy: StorageLocator.currentAppGroupContainer()
            )
            words += storage.loadUserWords(corruptFilePolicy: .leaveInPlace).value
            settings = storage.loadSettings().value
        }
        return TimelinePlanner.plan(words: words, settings: settings, now: now, timeZone: .current)
    }
}
