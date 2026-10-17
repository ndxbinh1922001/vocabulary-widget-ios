import Foundation
import Testing

@testable import VocabularyKit

enum Fixtures {
    static func word(_ id: String, term: String? = nil, source: WordSource = .builtIn) -> VocabularyWord {
        VocabularyWord(
            id: id,
            term: term ?? id,
            ipa: "/\(id)/",
            partOfSpeech: "noun",
            meaningVi: "nghĩa của \(id)",
            example: "An example with \(id).",
            source: source
        )
    }

    static func words(count: Int, prefix: String = "w", source: WordSource = .builtIn) -> [VocabularyWord] {
        (0..<count).map { word(String(format: "\(prefix)%03d", $0), source: source) }
    }

    static func calendar(_ timeZoneID: String) throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: timeZoneID))
        return calendar
    }

    static func date(
        _ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0,
        in calendar: Calendar
    ) throws -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return try #require(calendar.date(from: components))
    }
}

/// A fresh directory under the system temp folder, removed when the closure returns.
func withTemporaryDirectory<T>(_ body: (URL) throws -> T) throws -> T {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("VocabularyKitTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: url) }
    return try body(url)
}
