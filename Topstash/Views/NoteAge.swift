import Foundation

/// The short age a note row shows: "now", "5m", "2h", "3d", then the date ("Oct 28"), with the
/// year only when it isn't this year ("Oct 5, 2025").
enum NoteAge {
    static func text(created: Date, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let seconds = now.timeIntervalSince(created)
        switch seconds {
        case ..<60: return "now"
        case ..<3600: return "\(Int(seconds / 60))m"
        case ..<86400: return "\(Int(seconds / 3600))h"
        case ..<(7 * 86400): return "\(Int(seconds / 86400))d"
        default:
            var style = Date.FormatStyle(
                date: .omitted, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone
            )
            .month(.abbreviated).day()
            if calendar.component(.year, from: created) != calendar.component(.year, from: now) {
                style = style.year()
            }
            return created.formatted(style)
        }
    }
}
