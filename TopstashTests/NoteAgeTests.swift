import Foundation
import Testing

@testable import Topstash

/// The short age a note row shows on its right: minutes, hours, and days up to a week, then the date.
struct NoteAgeTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    private static let locale = Locale(identifier: "en_US")
    /// 2026-11-09 15:00 UTC.
    private static let now = Date(timeIntervalSince1970: 1_794_236_400)

    private func age(_ secondsAgo: TimeInterval) -> String {
        NoteAge.text(
            created: Self.now.addingTimeInterval(-secondsAgo), now: Self.now, calendar: Self.calendar,
            locale: Self.locale)
    }

    @Test(
        arguments: [
            (0, "now"),
            (59.0, "now"),
            (60.0, "1m"),
            (59 * 60.0, "59m"),
            (60 * 60.0, "1h"),
            (23 * 3600.0 + 59 * 60, "23h"),
            (24 * 3600.0, "1d"),
            (6 * 86400.0 + 23 * 3600, "6d"),
        ] as [(TimeInterval, String)])
    func recentNotesShowHowLongAgo(secondsAgo: TimeInterval, expected: String) {
        #expect(age(secondsAgo) == expected)
    }

    @Test func aWeekOrOlderShowsTheDate() {
        #expect(age(7 * 86400) == "Nov 2")
        #expect(age(12 * 86400) == "Oct 28")
    }

    @Test func anEarlierYearShowsTheYear() {
        #expect(age(400 * 86400) == "Oct 5, 2025")
    }

    /// A note from a clock that ran ahead, or a file copied in from another Mac.
    @Test func aDateInTheFutureShowsNow() {
        #expect(age(-3600) == "now")
    }
}
