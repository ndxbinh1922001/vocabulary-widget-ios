import Foundation

/// How often the widget switches to the next word: a custom duration from 20 seconds to 24 hours,
/// or once a day at local midnight.
///
/// Stored as a compact string so files written by earlier versions keep decoding:
/// `"15m"`, `"90s"`, `"2h"`, `"daily"`.
public enum RotationInterval: RawRepresentable, Codable, Hashable, Sendable {
    case every(amount: Int, unit: TimeUnit)
    case daily

    public enum TimeUnit: String, CaseIterable, Sendable {
        case seconds = "s"
        case minutes = "m"
        case hours = "h"

        public var seconds: Int {
            switch self {
            case .seconds: 1
            case .minutes: 60
            case .hours: 3_600
            }
        }
    }

    /// Why an amount/unit pair cannot be used.
    public enum ValidationIssue: Equatable, Sendable {
        case notPositive
        case tooShort(minimumSeconds: Int)
        case tooLong(maximumSeconds: Int)
    }

    /// Shortest supported interval, chosen by the user. Below `widgetReliableSeconds` the widget is
    /// best-effort, because WidgetKit throttles how often it refreshes.
    public static let minimumSeconds = 20
    public static let maximumSeconds = 86_400
    public static let widgetReliableSeconds = 60

    public static let minutes15 = RotationInterval.every(amount: 15, unit: .minutes)
    public static let minutes30 = RotationInterval.every(amount: 30, unit: .minutes)
    public static let hour1 = RotationInterval.every(amount: 1, unit: .hours)
    public static let hours3 = RotationInterval.every(amount: 3, unit: .hours)

    /// Quick choices offered in Settings next to the custom amount/unit editor.
    public static let presets: [RotationInterval] = [.minutes15, .minutes30, .hour1, .hours3, .daily]

    /// Checks a custom duration against the supported range.
    public static func validate(amount: Int, unit: TimeUnit) -> ValidationIssue? {
        guard amount > 0 else { return .notPositive }
        let (total, overflow) = amount.multipliedReportingOverflow(by: unit.seconds)
        if overflow || total > maximumSeconds { return .tooLong(maximumSeconds: maximumSeconds) }
        if total < minimumSeconds { return .tooShort(minimumSeconds: minimumSeconds) }
        return nil
    }

    /// A custom interval, or `nil` when the duration is outside 20 seconds ... 24 hours.
    public static func custom(amount: Int, unit: TimeUnit) -> RotationInterval? {
        validate(amount: amount, unit: unit) == nil ? .every(amount: amount, unit: unit) : nil
    }

    // MARK: RawRepresentable (also drives Codable)

    public var rawValue: String {
        switch self {
        case .every(let amount, let unit): "\(amount)\(unit.rawValue)"
        case .daily: "daily"
        }
    }

    /// Parses `"<amount><s|m|h>"` or `"daily"`; anything malformed or out of range is rejected.
    public init?(rawValue: String) {
        if rawValue == "daily" {
            self = .daily
            return
        }
        guard let last = rawValue.last, let unit = TimeUnit(rawValue: String(last)) else { return nil }
        let digits = rawValue.dropLast()
        guard !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isNumber }), let amount = Int(digits),
            let interval = Self.custom(amount: amount, unit: unit)
        else { return nil }
        self = interval
    }

    // MARK: Slots

    /// `true` for `.daily` and for custom durations inside the supported range.
    public var isValid: Bool {
        switch self {
        case .every(let amount, let unit): Self.validate(amount: amount, unit: unit) == nil
        case .daily: true
        }
    }

    /// Duration in seconds, or `nil` for `.daily`.
    public var durationSeconds: Int? {
        switch self {
        case .every(let amount, let unit):
            let (total, overflow) = amount.multipliedReportingOverflow(by: unit.seconds)
            return overflow ? Int.max : total
        case .daily:
            return nil
        }
    }

    /// Number of rotation slots in a regular (24-hour) local day. When the duration does not divide
    /// a day evenly, the last slot ends early at midnight.
    public var slotsPerDay: Int {
        guard let seconds = clampedSeconds else { return 1 }
        return (Self.maximumSeconds + seconds - 1) / seconds
    }

    /// Length of one slot in seconds, or `nil` for `.daily`, which follows local midnight.
    public var slotDuration: TimeInterval? {
        clampedSeconds.map(TimeInterval.init)
    }

    /// The duration forced into the supported range, so a value built directly with an invalid
    /// amount can never produce a zero-length or multi-day slot.
    private var clampedSeconds: Int? {
        durationSeconds.map { min(max($0, Self.minimumSeconds), Self.maximumSeconds) }
    }
}

/// Which words take part in the rotation and in list filtering.
public enum WordSourceFilter: String, Codable, Sendable, CaseIterable {
    case all
    case builtIn
    case user

    public func includes(_ word: VocabularyWord) -> Bool {
        switch self {
        case .all: true
        case .builtIn: word.source == .builtIn
        case .user: word.source == .user
        }
    }
}

/// User preferences shared by the app (writer) and the widget (reader).
public struct RotationSettings: Codable, Equatable, Sendable {
    public var interval: RotationInterval
    public var sourceFilter: WordSourceFilter

    public static let `default` = RotationSettings(interval: .hour1, sourceFilter: .all)

    public init(interval: RotationInterval, sourceFilter: WordSourceFilter) {
        self.interval = interval
        self.sourceFilter = sourceFilter
    }
}
