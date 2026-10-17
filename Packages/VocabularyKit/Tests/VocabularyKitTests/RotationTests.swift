import Foundation
import Testing

@testable import VocabularyKit

@Suite("WordRotation")
struct RotationTests {
    @Test("Input order does not affect the chosen word")
    func independentOfInputOrder() throws {
        let calendar = try Fixtures.calendar("Asia/Ho_Chi_Minh")
        let words = Fixtures.words(count: 30)
        let first = WordRotation(words: words, interval: .hour1, timeZone: calendar.timeZone)
        let second = WordRotation(words: words.reversed(), interval: .hour1, timeZone: calendar.timeZone)
        let start = try Fixtures.date(2026, 10, 16, in: calendar)

        for hour in 0..<200 {
            let date = start.addingTimeInterval(Double(hour) * 3_600 + 60)
            #expect(first.word(at: date) == second.word(at: date))
        }
    }

    @Test("Every word appears exactly once per cycle", arguments: [1, 2, 3, 7, 123])
    func fullCoveragePerCycle(count: Int) {
        let rotation = WordRotation(words: Fixtures.words(count: count), interval: .hour1)
        for cycle in [0, 1, 17, 739_000] {
            let ids = (cycle * count..<(cycle + 1) * count).compactMap { rotation.word(forSlot: $0)?.id }
            #expect(ids.count == count)
            #expect(Set(ids).count == count)
        }
    }

    @Test("The same word never shows twice in a row when there are more than two words")
    func noBackToBackRepeats() {
        let rotation = WordRotation(words: Fixtures.words(count: 4), interval: .hour1)
        let ids = (0..<4_000).compactMap { rotation.word(forSlot: $0)?.id }
        for (previous, next) in zip(ids, ids.dropFirst()) {
            #expect(previous != next)
        }
    }

    @Test("Different seeds give different orders")
    func seedMatters() {
        let words = Fixtures.words(count: 20)
        let first = WordRotation(words: words, interval: .hour1, seed: 1)
        let second = WordRotation(words: words, interval: .hour1, seed: 2)
        let firstIDs = (0..<20).compactMap { first.word(forSlot: $0)?.id }
        let secondIDs = (0..<20).compactMap { second.word(forSlot: $0)?.id }
        #expect(firstIDs != secondIDs)
    }

    @Test("An empty list has no word and no upcoming entries")
    func emptyList() {
        let rotation = WordRotation(words: [], interval: .hour1)
        #expect(rotation.word(at: Date()) == nil)
        #expect(rotation.upcoming(after: Date(), count: 5).isEmpty)
    }

    @Test("3-hour slots start at local midnight in Vietnam")
    func localSlotBoundaries() throws {
        let calendar = try Fixtures.calendar("Asia/Ho_Chi_Minh")
        let rotation = WordRotation(words: Fixtures.words(count: 50), interval: .hours3, timeZone: calendar.timeZone)

        let beforeNine = try Fixtures.date(2026, 10, 16, 8, 59, in: calendar)
        let nine = try Fixtures.date(2026, 10, 16, 9, 0, in: calendar)
        #expect(rotation.slot(for: nine) == rotation.slot(for: beforeNine) + 1)
        #expect(rotation.nextBoundary(after: beforeNine) == nine)
        #expect(rotation.nextBoundary(after: nine) == (try Fixtures.date(2026, 10, 16, 12, 0, in: calendar)))

        let lateEvening = try Fixtures.date(2026, 10, 16, 22, 30, in: calendar)
        #expect(rotation.nextBoundary(after: lateEvening) == (try Fixtures.date(2026, 10, 17, in: calendar)))
    }

    @Test("Daily rotation changes exactly at local midnight")
    func dailyRotation() throws {
        let calendar = try Fixtures.calendar("Asia/Ho_Chi_Minh")
        let rotation = WordRotation(words: Fixtures.words(count: 10), interval: .daily, timeZone: calendar.timeZone)

        let morning = try Fixtures.date(2026, 10, 16, 0, 0, in: calendar)
        let night = try Fixtures.date(2026, 10, 16, 23, 59, in: calendar)
        let nextDay = try Fixtures.date(2026, 10, 17, 0, 0, in: calendar)

        #expect(rotation.slot(for: morning) == rotation.slot(for: night))
        #expect(rotation.slot(for: nextDay) == rotation.slot(for: night) + 1)
        #expect(rotation.word(at: nextDay) != rotation.word(at: night))
        #expect(rotation.nextBoundary(after: try Fixtures.date(2026, 10, 16, 15, 0, in: calendar)) == nextDay)
    }

    @Test(
        "DST days keep slots unique and boundaries ordered",
        arguments: [
            (3, 8, 23),  // 23-hour day: one slot is skipped
            (11, 1, 24),  // 25-hour day: the last slot lasts two hours
            (10, 16, 24),  // regular day
        ]
    )
    func daylightSavingTime(month: Int, day: Int, expectedBoundaries: Int) throws {
        let calendar = try Fixtures.calendar("America/New_York")
        let rotation = WordRotation(words: Fixtures.words(count: 100), interval: .hour1, timeZone: calendar.timeZone)
        let dayStart = try Fixtures.date(2026, month, day, in: calendar)
        let nextDayStart = calendar.startOfDay(for: dayStart.addingTimeInterval(30 * 3_600))

        var boundaries: [Date] = []
        var cursor = dayStart
        while cursor < nextDayStart {
            cursor = rotation.nextBoundary(after: cursor)
            boundaries.append(cursor)
        }

        #expect(boundaries.count == expectedBoundaries)
        #expect(boundaries.last == nextDayStart)
        let slots = ([dayStart] + boundaries).map(rotation.slot(for:))
        #expect(zip(slots, slots.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test("upcoming lists the words of the next slots in order")
    func upcoming() throws {
        let calendar = try Fixtures.calendar("Asia/Ho_Chi_Minh")
        let rotation = WordRotation(words: Fixtures.words(count: 12), interval: .minutes30, timeZone: calendar.timeZone)
        let now = try Fixtures.date(2026, 10, 16, 10, 10, in: calendar)

        let next = rotation.upcoming(after: now, count: 3)
        #expect(
            next.map(\.start) == [
                try Fixtures.date(2026, 10, 16, 10, 30, in: calendar),
                try Fixtures.date(2026, 10, 16, 11, 0, in: calendar),
                try Fixtures.date(2026, 10, 16, 11, 30, in: calendar),
            ])
        for scheduled in next {
            #expect(scheduled.word == rotation.word(at: scheduled.start))
        }
    }

    @Test(
        "daysFromCivil matches reference day numbers",
        arguments: [
            (1970, 1, 1, 0), (1969, 12, 31, -1), (2000, 3, 1, 11_017), (2026, 10, 16, 20_742), (1600, 2, 29, -135_081),
        ]
    )
    func daysFromCivil(year: Int, month: Int, day: Int, expected: Int) {
        #expect(WordRotation.daysFromCivil(year: year, month: month, day: day) == expected)
    }

    @Test("A whole local day maps to one day number east of UTC (regression: ordinality ignored the time zone)")
    func localDayNumberFollowsTimeZone() throws {
        let calendar = try Fixtures.calendar("Asia/Ho_Chi_Minh")
        let rotation = WordRotation(words: Fixtures.words(count: 3), interval: .daily, timeZone: calendar.timeZone)
        let midnight = try Fixtures.date(2026, 10, 16, 0, 0, in: calendar)
        let sevenAM = try Fixtures.date(2026, 10, 16, 7, 0, in: calendar)
        let lastMinute = try Fixtures.date(2026, 10, 16, 23, 59, in: calendar)
        #expect(rotation.localDayNumber(of: midnight) == 20_742)
        #expect(rotation.localDayNumber(of: sevenAM) == 20_742)
        #expect(rotation.localDayNumber(of: lastMinute) == 20_742)
    }

    @Test("The device calendar system does not change the word, only the time zone does")
    func calendarSystemIndependence() throws {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = try #require(TimeZone(identifier: "Asia/Bangkok"))
        let gregorian = try Fixtures.calendar("Asia/Bangkok")
        let date = try Fixtures.date(2026, 10, 16, 9, 30, in: gregorian)
        let words = Fixtures.words(count: 25)

        let fromBuddhist = WordRotation(words: words, interval: .hour1, timeZone: buddhist.timeZone)
        let fromGregorian = WordRotation(words: words, interval: .hour1, timeZone: gregorian.timeZone)
        #expect(fromBuddhist.slot(for: date) == fromGregorian.slot(for: date))
        #expect(fromBuddhist.word(at: date) == fromGregorian.word(at: date))
    }

    @Test("SplitMix64 produces the reference sequence for seed 0")
    func splitMixReference() {
        var generator = SplitMix64(seed: 0)
        #expect(generator.next() == 0xE220_A839_7B1D_CDAF)
        #expect(generator.next() == 0x6E78_9E6A_A1B9_65F4)
    }
}

@Suite("RotationInterval")
struct RotationIntervalTests {
    @Test(
        "Stored strings round-trip, including values written by earlier versions",
        arguments: [
            ("15m", RotationInterval.minutes15), ("30m", .minutes30), ("1h", .hour1), ("3h", .hours3),
            ("daily", .daily),
            ("20s", .every(amount: 20, unit: .seconds)), ("90s", .every(amount: 90, unit: .seconds)),
            ("7m", .every(amount: 7, unit: .minutes)), ("24h", .every(amount: 24, unit: .hours)),
        ]
    )
    func rawValues(raw: String, interval: RotationInterval) throws {
        #expect(RotationInterval(rawValue: raw) == interval)
        #expect(interval.rawValue == raw)
        let decoded = try JSONDecoder().decode(RotationInterval.self, from: JSONEncoder().encode(interval))
        #expect(decoded == interval)
    }

    @Test(
        "Malformed or out-of-range strings are rejected",
        arguments: [
            "", "s", "19s", "0m", "-5m", "25h", "1441m", "86401s", "1.5h", "15", "15x", "１５m", "dailyy", " 15m",
        ]
    )
    func rejectsInvalid(raw: String) {
        #expect(RotationInterval(rawValue: raw) == nil)
    }

    @Test("Validation enforces 20 seconds ... 24 hours without overflowing")
    func validation() {
        #expect(RotationInterval.validate(amount: 20, unit: .seconds) == nil)
        #expect(RotationInterval.validate(amount: 24, unit: .hours) == nil)
        #expect(RotationInterval.validate(amount: 19, unit: .seconds) == .tooShort(minimumSeconds: 20))
        #expect(RotationInterval.validate(amount: 1441, unit: .minutes) == .tooLong(maximumSeconds: 86_400))
        #expect(RotationInterval.validate(amount: 0, unit: .hours) == .notPositive)
        #expect(RotationInterval.validate(amount: Int.max, unit: .hours) == .tooLong(maximumSeconds: 86_400))
        #expect(RotationInterval.custom(amount: 10, unit: .seconds) == nil)
        #expect(RotationInterval.every(amount: 10, unit: .seconds).isValid == false)
    }

    @Test(
        "Slots per day round up when the duration does not divide a day",
        arguments: [
            (RotationInterval.minutes15, 96), (.every(amount: 20, unit: .seconds), 4_320),
            (.every(amount: 7, unit: .minutes), 206), (.every(amount: 24, unit: .hours), 1), (.daily, 1),
        ]
    )
    func slotsPerDay(interval: RotationInterval, expected: Int) {
        #expect(interval.slotsPerDay == expected)
    }

    @Test("Settings files with an unsupported interval fall back to defaults")
    func settingsWithInvalidInterval() throws {
        try withTemporaryDirectory { directory in
            let storage = VocabularyStorage(directory: directory)
            try Data(#"{"version":1,"interval":"10s","sourceFilter":"user"}"#.utf8).write(to: storage.settingsURL)
            #expect(storage.loadSettings().value == .default)

            try storage.saveSettings(
                RotationSettings(interval: .every(amount: 45, unit: .seconds), sourceFilter: .user))
            #expect(storage.loadSettings().value.interval == .every(amount: 45, unit: .seconds))
        }
    }

    @Test("A 7-minute rotation ends its last, shorter slot at local midnight")
    func uneven7MinuteDay() throws {
        let calendar = try Fixtures.calendar("Asia/Ho_Chi_Minh")
        let rotation = WordRotation(
            words: Fixtures.words(count: 50), interval: .every(amount: 7, unit: .minutes), timeZone: calendar.timeZone)
        let lastSlotStart = try Fixtures.date(2026, 10, 16, 23, 55, in: calendar)
        let insideLastSlot = try Fixtures.date(2026, 10, 16, 23, 58, in: calendar)
        let midnight = try Fixtures.date(2026, 10, 17, in: calendar)

        #expect(rotation.nextBoundary(after: try Fixtures.date(2026, 10, 16, 23, 50, in: calendar)) == lastSlotStart)
        #expect(rotation.nextBoundary(after: insideLastSlot) == midnight)
        #expect(rotation.slot(for: midnight) == rotation.slot(for: insideLastSlot) + 1)
    }

    @Test("A 20-second rotation changes word every 20 seconds")
    func twentySeconds() throws {
        let calendar = try Fixtures.calendar("Asia/Ho_Chi_Minh")
        let rotation = WordRotation(
            words: Fixtures.words(count: 30), interval: .every(amount: 20, unit: .seconds), timeZone: calendar.timeZone)
        let start = try Fixtures.date(2026, 10, 16, 10, 0, in: calendar)
        let next = rotation.upcoming(after: start.addingTimeInterval(5), count: 3).map(\.start)
        #expect(next == [start.addingTimeInterval(20), start.addingTimeInterval(40), start.addingTimeInterval(60)])
        #expect(rotation.word(at: start) != rotation.word(at: start.addingTimeInterval(20)))
    }
}
