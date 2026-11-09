import CoreGraphics
import Testing

@testable import Topstash

/// The size of the panel's shape in each mode (`PanelLayout.shapeSize`). Expected heights are worked
/// out by hand from the layout: notch clearance 38, card 84, section spacing 8 (twice), rows of 40
/// with 2 between them, "Show all" 28, bottom padding 14.
struct PanelShapeSizeTests {
    @Test func closedUnderANotchIsTheNotchSize() {
        let notch = CGSize(width: 185, height: 32)

        let size = PanelLayout.shapeSize(for: .closed, closedSize: notch, noteCount: 3)

        #expect(size == CGSize(width: 185, height: 32))
    }

    @Test func closedWithoutANotchIsTheHoverStripWithNoHeight() {
        let hoverStrip = CGSize(width: 200, height: 0)

        let size = PanelLayout.shapeSize(for: .closed, closedSize: hoverStrip, noteCount: 3)

        #expect(size == CGSize(width: 200, height: 0))
    }

    @Test(arguments: [
        (0, 220.0),  // "No notes yet" takes one row's height.
        (1, 220.0),
        (2, 262.0),
        (3, 304.0),
        (4, 346.0),
        (5, 388.0),
        (6, 388.0),  // Only the five newest are listed.
        (40, 388.0),
    ])
    func openGrowsWithTheRecentNotes(noteCount: Int, height: Double) {
        let size = PanelLayout.shapeSize(for: .open, closedSize: CGSize(width: 185, height: 32), noteCount: noteCount)

        #expect(size == CGSize(width: 380, height: height))
    }

    @Test func searchHasAFixedSize() {
        let size = PanelLayout.shapeSize(for: .search, closedSize: CGSize(width: 185, height: 32), noteCount: 3)

        #expect(size == CGSize(width: 400, height: 520))
    }

    @Test func shortcutFeedbackShowsOnlyTheSaveCard() {
        let size = PanelLayout.shapeSize(for: .feedback, closedSize: CGSize(width: 185, height: 32), noteCount: 3)

        #expect(size == CGSize(width: 380, height: 136))
    }
}
