import Foundation

/// A word scheduled to appear from `start` until the next slot boundary.
public struct ScheduledWord: Equatable, Sendable {
    public let start: Date
    public let word: VocabularyWord

    public init(start: Date, word: VocabularyWord) {
        self.start = start
        self.word = word
    }
}

/// Deterministic mapping from a moment in time to a word.
///
/// The same words, interval, time zone and seed always give the same word for the same moment,
/// so the app preview and the widget agree and timeline reloads never reshuffle the current word.
///
/// Time is split into local slots: `interval.slotsPerDay` slots per day, starting at local midnight
/// (a 25-hour DST day repeats its last word for an extra hour, a 23-hour day skips one).
/// Slots are grouped into cycles of `words.count`; each cycle shows every word exactly once, in an
/// order shuffled with SplitMix64 seeded by `seed ^ cycle`.
public struct WordRotation: Sendable {
    public static let defaultSeed: UInt64 = 0x5EED_0F70_CAB0_0001

    /// Candidate words sorted by id, the only ordering input that is stable across processes.
    public let words: [VocabularyWord]
    public let interval: RotationInterval
    public let seed: UInt64
    /// Gregorian calendar in the requested time zone. The user's calendar system (Buddhist,
    /// Japanese, ...) must not change which word is shown, only the time zone may.
    private let calendar: Calendar

    public var timeZone: TimeZone {
        calendar.timeZone
    }

    public init(
        words: [VocabularyWord],
        interval: RotationInterval,
        timeZone: TimeZone = .current,
        seed: UInt64 = WordRotation.defaultSeed
    ) {
        self.words = words.sorted { $0.id < $1.id }
        self.interval = interval
        self.seed = seed
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    /// Global slot index of `date`.
    public func slot(for date: Date) -> Int {
        let dayStart = calendar.startOfDay(for: date)
        let dayIndex = localDayNumber(of: date)
        guard let duration = interval.slotDuration else { return dayIndex }
        let elapsed = date.timeIntervalSince(dayStart)
        let slotInDay = min(max(Int(elapsed / duration), 0), interval.slotsPerDay - 1)
        return dayIndex * interval.slotsPerDay + slotInDay
    }

    /// First slot boundary strictly after `date`.
    public func nextBoundary(after date: Date) -> Date {
        let dayStart = calendar.startOfDay(for: date)
        let nextDayStart = startOfNextDay(after: dayStart)
        guard let duration = interval.slotDuration else { return nextDayStart }
        let slotInDay = Int(date.timeIntervalSince(dayStart) / duration)
        guard slotInDay + 1 < interval.slotsPerDay else { return nextDayStart }
        let candidate = dayStart.addingTimeInterval(Double(slotInDay + 1) * duration)
        return min(candidate, nextDayStart)
    }

    public func word(at date: Date) -> VocabularyWord? {
        word(forSlot: slot(for: date))
    }

    public func word(forSlot slot: Int) -> VocabularyWord? {
        guard !words.isEmpty else { return nil }
        let count = words.count
        let cycle = Self.floorDivide(slot, count)
        let position = slot - cycle * count
        return words[permutation(forCycle: cycle)[position]]
    }

    /// The next `count` scheduled words after the slot containing `date`.
    public func upcoming(after date: Date, count: Int) -> [ScheduledWord] {
        guard !words.isEmpty, count > 0 else { return [] }
        var result: [ScheduledWord] = []
        result.reserveCapacity(count)
        var boundary = date
        for _ in 0..<count {
            boundary = nextBoundary(after: boundary)
            guard let word = word(at: boundary) else { break }
            result.append(ScheduledWord(start: boundary, word: word))
        }
        return result
    }

    // MARK: - Internals

    /// Shuffled word indices for one cycle. When a cycle would start with the word that ended the
    /// previous cycle, its first two entries are swapped so the same word never shows twice in a row.
    func permutation(forCycle cycle: Int) -> [Int] {
        var order = Self.basePermutation(count: words.count, seed: seed ^ UInt64(bitPattern: Int64(cycle)))
        // With two words, swapping would change the previous cycle's last entry too; accept a repeat there.
        if words.count > 2 {
            let previous = Self.basePermutation(
                count: words.count,
                seed: seed ^ UInt64(bitPattern: Int64(cycle - 1))
            )
            if order[0] == previous[words.count - 1] {
                order.swapAt(0, 1)
            }
        }
        return order
    }

    static func basePermutation(count: Int, seed: UInt64) -> [Int] {
        var indices = Array(0..<count)
        guard count > 1 else { return indices }
        var generator = SplitMix64(seed: seed)
        for index in stride(from: count - 1, to: 0, by: -1) {
            indices.swapAt(index, generator.nextIndex(upperBound: index + 1))
        }
        return indices
    }

    /// Days since 1970-01-01 of the local calendar date containing `date`.
    ///
    /// Computed arithmetically from the local year/month/day because
    /// `Calendar.ordinality(of: .day, in: .era, for:)` does not follow the calendar's time zone
    /// (in UTC+7 it reports different values for 00:00 and 23:59 of the same local day).
    func localDayNumber(of date: Date) -> Int {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return Self.floorDivide(Int(date.timeIntervalSince1970.rounded(.down)), 86_400)
        }
        return Self.daysFromCivil(year: year, month: month, day: day)
    }

    /// Days since 1970-01-01 for a proleptic Gregorian date (Howard Hinnant's `days_from_civil`).
    static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let shiftedYear = month <= 2 ? year - 1 : year
        let era = floorDivide(shiftedYear, 400)
        let yearOfEra = shiftedYear - era * 400
        let monthFromMarch = (month + 9) % 12
        let dayOfYear = (153 * monthFromMarch + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    private func startOfNextDay(after dayStart: Date) -> Date {
        guard let sameTimeTomorrow = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return dayStart.addingTimeInterval(86_400)
        }
        return calendar.startOfDay(for: sameTimeTomorrow)
    }

    private static func floorDivide(_ value: Int, _ divisor: Int) -> Int {
        let quotient = value / divisor
        return (value % divisor != 0 && (value < 0) != (divisor < 0)) ? quotient - 1 : quotient
    }
}

/// Small, fast, seedable generator. Implemented here (instead of relying on the standard library's
/// bounded random helpers) so the sequence is identical on every OS version.
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    /// Uniform-enough index in `0..<upperBound` (multiply-high mapping; bias is negligible for word lists).
    mutating func nextIndex(upperBound: Int) -> Int {
        precondition(upperBound > 0, "upperBound must be positive")
        return Int(next().multipliedFullWidth(by: UInt64(upperBound)).high)
    }
}
