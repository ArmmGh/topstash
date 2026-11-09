import Foundation
import Testing

@testable import Topstash

/// The save card's `meta` line under the clipboard preview.
@MainActor
struct SaveCardTextTests {
    @Test(arguments: [
        (1, "Click to save · 1 character"),
        (12, "Click to save · 12 characters"),
        (1284, "Click to save · 1,284 characters"),
    ])
    func hintNamesTheActionAndTheLength(count: Int, expected: String) {
        #expect(SaveCard.saveHintText(count, locale: Locale(identifier: "en_US")) == expected)
    }
}
