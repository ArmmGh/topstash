import CoreGraphics
import Testing

@testable import Topstash

/// The save card fits its text, so the shape's height can be known before layout. Heights are
/// worked out by hand: `inset` 12 above and below, 16 pt preview and label lines, the 4 pt gap, and
/// the 13 pt hint line.
@MainActor
struct SaveCardHeightTests {
    @Test(arguments: [
        ("Buy milk", 1),
        ("Buy milk\nand eggs", 2),
        ("one\ntwo\nthree\nfour", 3),  // Capped at the card's three lines.
        (String(repeating: "word ", count: 14), 2),  // 70 characters wrap once at 320 pt.
        (String(repeating: "word ", count: 200), 3),
    ])
    func previewLinesAreMeasuredAtTheCardsWidth(text: String, lines: Int) {
        #expect(PanelLayout.previewLineCount(text) == lines)
    }

    @Test(arguments: [
        (SaveCardState.preview(text: "Buy milk", characterCount: 8), 57.0),
        (.preview(text: "Buy milk\nand eggs", characterCount: 17), 73.0),
        (.preview(text: "one\ntwo\nthree\nfour", characterCount: 18), 89.0),
        // A label and a hint: as tall as a one-line preview.
        (.readyWithoutPreview, 57.0),
        (.accessDenied, 57.0),
        // Only a label.
        (.alreadySaved, 40.0),
        (.nothingToSave, 40.0),
        (.failed, 40.0),
    ])
    func cardHeightFitsItsText(state: SaveCardState, height: Double) {
        #expect(Double(PanelLayout.saveCardHeight(for: state)) == height)
    }

    @Test(arguments: [(57.0, 1), (73.0, 2), (89.0, 3)])
    func aPreviewCardShowsTheLinesItWasSizedFor(height: Double, lines: Int) {
        #expect(PanelLayout.previewLines(inCardHeight: height) == lines)
    }

    @Test func theSavedCheckmarkKeepsTheHeightOfTheCardItReplaced() {
        let panel = PanelModel()

        panel.saveCard = .preview(text: "one\ntwo\nthree", characterCount: 13)
        panel.saveCard = .saved

        #expect(panel.saveCardHeight == 89)
    }

    @Test func theNextCardSetsItsOwnHeight() {
        let panel = PanelModel()

        panel.saveCard = .preview(text: "one\ntwo\nthree", characterCount: 13)
        panel.saveCard = .saved
        panel.saveCard = .alreadySaved

        #expect(panel.saveCardHeight == 40)
    }
}
