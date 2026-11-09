import CoreGraphics
import Testing

@testable import Topstash

/// Keeping the keyboard selection in view (`PanelLayout.scrollOffset`): scroll only when the selected
/// row is outside the visible part of the results, and only as far as needed. Rows are 40 pt with no gap.
struct SelectionScrollTests {
    /// Room for three and a half rows.
    let viewport: CGFloat = 140

    @Test func aVisibleRowDoesNotScroll() {
        #expect(PanelLayout.scrollOffset(showingRow: 0, offset: 0, viewportHeight: viewport) == nil)
        #expect(PanelLayout.scrollOffset(showingRow: 2, offset: 0, viewportHeight: viewport) == nil)
        #expect(PanelLayout.scrollOffset(showingRow: 3, offset: 20, viewportHeight: viewport) == nil)
    }

    @Test func aRowBelowTheViewScrollsUntilItsBottomIsAtTheBottom() {
        // Row 3 is 120–160; the view shows 0–140.
        #expect(PanelLayout.scrollOffset(showingRow: 3, offset: 0, viewportHeight: viewport) == 20)
    }

    @Test func aRowAboveTheViewScrollsUntilItsTopIsAtTheTop() {
        // Row 1 is 40–80; the view shows 50–190.
        #expect(PanelLayout.scrollOffset(showingRow: 1, offset: 50, viewportHeight: viewport) == 40)
    }
}
