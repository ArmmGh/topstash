import CoreGraphics
import Foundation
import Testing

@testable import Topstash

/// The header band beside the notch.
@MainActor
struct PanelHeaderTests {
    @Test(arguments: [
        (32.0, 32.0),  // A notch.
        (38.0, 38.0),
        (24.0, 28.0),  // A menu bar shorter than the header's button: the button still fits.
    ])
    func headerIsAsTallAsTheNotchOrMenuBar(hoverAreaHeight: Double, height: Double) {
        #expect(Double(PanelLayout.headerHeight(forHoverAreaHeight: hoverAreaHeight)) == height)
    }

    @Test(arguments: [
        (185.0, 95.5),  // (400 − 2 × 12 − 185) / 2: each side stops at the notch.
        (0.0, 188.0),  // No notch: each side may take half the width.
    ])
    func eachSideOfTheHeaderStopsAtTheNotch(notchWidth: Double, sideWidth: Double) {
        #expect(Double(PanelLayout.headerSideWidth(notchWidth: notchWidth)) == sideWidth)
    }

    @Test func aPanelUnderANotchKnowsTheNotchWidth() {
        let panel = PanelModel()
        panel.closedSize = CGSize(width: 185, height: 32)

        #expect(panel.notchWidth == 185)
    }

    @Test func aPanelWithoutANotchHasNoNotchWidth() {
        let panel = PanelModel()
        panel.closedSize = CGSize(width: 200, height: 0)

        #expect(panel.notchWidth == 0)
    }

    @Test(
        arguments: [
            (12, nil, "12"),  // The list: every note.
            (1284, nil, "1,284"),
            (12, 4, "4 of 12"),  // Search: the matches of every note.
            (1284, 0, "0 of 1,284"),
        ] as [(Int, Int?, String)])
    func countShowsTheNotesOrTheMatches(total: Int, matches: Int?, expected: String) {
        let text = PanelHeader.countText(total: total, matches: matches, locale: Locale(identifier: "en_US"))

        #expect(text == expected)
    }
}
