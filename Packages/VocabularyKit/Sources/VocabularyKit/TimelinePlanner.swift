import Foundation

/// Platform-neutral description of a widget timeline.
public struct TimelinePlan: Equatable, Sendable {
    public enum ReloadPolicy: Equatable, Sendable {
        /// Ask for a new timeline after the last entry.
        case atEnd
        /// Wait until the app reloads timelines (used when there is nothing to show).
        case never
    }

    public struct Entry: Equatable, Sendable {
        public let date: Date
        /// `nil` means "no words available" and renders a placeholder.
        public let word: VocabularyWord?
    }

    public let entries: [Entry]
    public let reloadPolicy: ReloadPolicy
}

public enum TimelinePlanner {
    /// Upper bound on entries per timeline. With `.atEnd` reloads this keeps even the 20-second
    /// minimum at about 36 timeline requests a day, inside WidgetKit's daily refresh budget.
    public static let maximumEntries = 120

    /// Builds the widget timeline: the current word at `now`, then one entry per following slot
    /// boundary, `interval.slotsPerDay` entries in total (96 / 48 / 24 / 8 for the presets) but at most
    /// `maximumEntries`, or `now` plus the next midnight for `.daily`. WidgetKit asks for a new
    /// timeline once the last entry is reached.
    ///
    /// WidgetKit's reload budget counts timeline requests, not entries, so a full day of 15-minute
    /// entries costs a single reload.
    public static func plan(
        words: [VocabularyWord],
        settings: RotationSettings,
        now: Date,
        timeZone: TimeZone = .current,
        seed: UInt64 = WordRotation.defaultSeed
    ) -> TimelinePlan {
        let candidates = words.filter(settings.sourceFilter.includes)
        let rotation = WordRotation(words: candidates, interval: settings.interval, timeZone: timeZone, seed: seed)

        guard let current = rotation.word(at: now) else {
            return TimelinePlan(entries: [TimelinePlan.Entry(date: now, word: nil)], reloadPolicy: .never)
        }

        let boundaryCount = min(max(settings.interval.slotsPerDay - 1, 1), maximumEntries - 1)
        let upcoming = rotation.upcoming(after: now, count: boundaryCount)
        let entries =
            [TimelinePlan.Entry(date: now, word: current)]
            + upcoming.map { TimelinePlan.Entry(date: $0.start, word: $0.word) }
        return TimelinePlan(entries: entries, reloadPolicy: .atEnd)
    }
}
