import CoreGraphics
import Testing

@testable import Topstash

/// The size of the panel's shape in each mode (`PanelLayout.shapeSize`). Expected heights are worked
/// out by hand from the layout: the header (the notch's height, 32 here), section spacing 8, the
/// card's height, 8 again, rows of 40 with no gap between them, and the bottom inset 12. The width is
/// 400 in every open mode.
@MainActor
struct PanelShapeSizeTests {
    let notch = CGSize(width: 185, height: 32)

    /// A panel under a 32 pt notch whose card previews three lines (89 pt).
    func makePanel(_ mode: PanelModel.Mode, header: CGFloat = 32, card: SaveCardState? = nil) -> PanelModel {
        let panel = PanelModel()
        panel.closedSize = notch
        panel.headerHeight = header
        panel.saveCard = card ?? .preview(text: "one\ntwo\nthree", characterCount: 13)
        panel.mode = mode
        return panel
    }

    @Test func closedUnderANotchIsTheNotchSize() {
        let size = PanelLayout.shapeSize(for: makePanel(.closed), noteCount: 3)

        #expect(size == CGSize(width: 185, height: 32))
    }

    @Test func closedWithoutANotchIsTheHoverStripWithNoHeight() {
        let panel = makePanel(.closed)
        panel.closedSize = CGSize(width: 200, height: 0)

        let size = PanelLayout.shapeSize(for: panel, noteCount: 3)

        #expect(size == CGSize(width: 200, height: 0))
    }

    @Test(arguments: [
        (0, 189.0),  // "No notes yet" takes one row's height.
        (1, 189.0),
        (2, 229.0),
        (3, 269.0),
        (4, 309.0),
        (5, 349.0),
        (6, 349.0),  // Only the five newest are listed.
        (40, 349.0),
    ])
    func openGrowsWithTheRecentNotes(noteCount: Int, height: Double) {
        let size = PanelLayout.shapeSize(for: makePanel(.open), noteCount: noteCount)

        #expect(size.width == 400)
        #expect(Double(size.height) == height)
    }

    @Test(arguments: [
        (SaveCardState.alreadySaved, 220.0),
        (.readyWithoutPreview, 237.0),
        (.preview(text: "one\ntwo", characterCount: 7), 253.0),
    ])
    func openFitsTheSaveCard(card: SaveCardState, height: Double) {
        let size = PanelLayout.shapeSize(for: makePanel(.open, card: card), noteCount: 3)

        #expect(Double(size.height) == height)
    }

    @Test func openFollowsTheHeaderHeight() {
        let size = PanelLayout.shapeSize(for: makePanel(.open, header: 38), noteCount: 3)

        #expect(Double(size.height) == 275)
    }

    @Test func searchHasAFixedSize() {
        let size = PanelLayout.shapeSize(for: makePanel(.search), noteCount: 3)

        #expect(size == CGSize(width: 400, height: 520))
    }

    @Test func shortcutFeedbackShowsOnlyTheSaveCardUnderTheHeader() {
        let size = PanelLayout.shapeSize(for: makePanel(.feedback), noteCount: 3)

        #expect(size == CGSize(width: 400, height: 141))
    }

    @Test func listAndSearchHaveTheSameWidth() {
        let open = PanelLayout.shapeSize(for: makePanel(.open), noteCount: 5)
        let search = PanelLayout.shapeSize(for: makePanel(.search), noteCount: 5)

        #expect(open.width == search.width)
    }

    @Test func theWindowFitsTheTallestPanel() {
        let tallest = PanelLayout.shapeSize(for: makePanel(.open, header: PanelLayout.maxHeaderHeight), noteCount: 5)

        #expect(PanelLayout.windowSize.height >= tallest.height + PanelLayout.shadowPadding)
    }
}
