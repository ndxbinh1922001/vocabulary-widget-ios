import Foundation
import Testing

@testable import VocabularyKit

@Suite("TimelinePlanner")
struct TimelinePlannerTests {
    private let words = Fixtures.words(count: 40) + Fixtures.words(count: 5, prefix: "u", source: .user)

    @Test(
        "Entry counts match the approved plan: 96 / 48 / 24 / 8, and 2 for daily",
        arguments: [
            (RotationInterval.minutes15, 96), (.minutes30, 48), (.hour1, 24), (.hours3, 8), (.daily, 2),
        ]
    )
    func entryCounts(interval: RotationInterval, expectedCount: Int) throws {
        let calendar = try Fixtures.calendar("Asia/Ho_Chi_Minh")
        let now = try Fixtures.date(2026, 10, 16, 10, 20, in: calendar)
        let plan = TimelinePlanner.plan(
            words: words, settings: RotationSettings(interval: interval, sourceFilter: .all), now: now,
            timeZone: calendar.timeZone)

        #expect(plan.entries.count == expectedCount)
        #expect(plan.reloadPolicy == .atEnd)
        #expect(plan.entries.first?.date == now)

        let dates = plan.entries.map(\.date)
        #expect(zip(dates, dates.dropFirst()).allSatisfy { $0 < $1 })
        let span = try #require(dates.last).timeIntervalSince(now)
        #expect(span > 0 && span <= 86_400)
    }

    @Test("Daily timelines have the current word and the next midnight")
    func dailyTimeline() throws {
        let calendar = try Fixtures.calendar("Asia/Ho_Chi_Minh")
        let now = try Fixtures.date(2026, 10, 16, 15, 0, in: calendar)
        let plan = TimelinePlanner.plan(
            words: words, settings: RotationSettings(interval: .daily, sourceFilter: .all), now: now,
            timeZone: calendar.timeZone)
        #expect(plan.entries.map(\.date) == [now, try Fixtures.date(2026, 10, 17, in: calendar)])
    }

    @Test("Entries match the rotation for the same filter, calendar and seed")
    func entriesMatchRotation() throws {
        let calendar = try Fixtures.calendar("Asia/Ho_Chi_Minh")
        let now = try Fixtures.date(2026, 10, 16, 10, 20, in: calendar)
        let settings = RotationSettings(interval: .minutes15, sourceFilter: .builtIn)
        let plan = TimelinePlanner.plan(words: words, settings: settings, now: now, timeZone: calendar.timeZone)
        let rotation = WordRotation(
            words: words.filter { $0.source == .builtIn }, interval: .minutes15, timeZone: calendar.timeZone)

        for entry in plan.entries {
            #expect(entry.word == rotation.word(at: entry.date))
            #expect(entry.word?.source == .builtIn)
        }
    }

    @Test(
        "Short custom intervals are capped so the widget stays inside its refresh budget",
        arguments: [
            (RotationInterval.every(amount: 20, unit: .seconds), 120, 20.0),
            (.every(amount: 1, unit: .minutes), 120, 60.0),
            (.every(amount: 2, unit: .hours), 12, 7_200.0),
        ]
    )
    func customIntervalEntries(interval: RotationInterval, expectedCount: Int, step: Double) throws {
        let calendar = try Fixtures.calendar("Asia/Ho_Chi_Minh")
        let now = try Fixtures.date(2026, 10, 16, 10, 0, in: calendar)
        let plan = TimelinePlanner.plan(
            words: words, settings: RotationSettings(interval: interval, sourceFilter: .all), now: now,
            timeZone: calendar.timeZone)
        #expect(plan.entries.count == expectedCount)
        #expect(plan.entries.count <= TimelinePlanner.maximumEntries)
        let dates = plan.entries.map(\.date)
        #expect(zip(dates, dates.dropFirst()).allSatisfy { $1.timeIntervalSince($0) == step })
    }

    @Test("No matching words yields a single placeholder entry and no automatic reload")
    func placeholder() throws {
        let now = Date(timeIntervalSince1970: 1_792_000_000)
        let plan = TimelinePlanner.plan(
            words: Fixtures.words(count: 3), settings: RotationSettings(interval: .hour1, sourceFilter: .user), now: now
        )
        #expect(plan.entries == [TimelinePlan.Entry(date: now, word: nil)])
        #expect(plan.reloadPolicy == .never)
    }
}
