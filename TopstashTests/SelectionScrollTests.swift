import CoreGraphics
import SwiftUI
import Testing

@testable import Topstash

/// Keeping the keyboard selection in view (`PanelLayout.scrollAnchor`): scroll only when the selected
/// row is outside the visible part of the results, and only as far as needed. Rows are 40 pt with no gap.
struct SelectionScrollTests {
    /// Room for three and a half rows.
    let viewport: CGFloat = 140

    @Test func aVisibleRowDoesNotScroll() {
        #expect(PanelLayout.scrollAnchor(row: 0, offset: 0, viewportHeight: viewport) == nil)
        #expect(PanelLayout.scrollAnchor(row: 2, offset: 0, viewportHeight: viewport) == nil)
        #expect(PanelLayout.scrollAnchor(row: 3, offset: 20, viewportHeight: viewport) == nil)
    }

    @Test func aRowBelowTheViewScrollsItToTheBottom() {
        // Row 3 is 120–160; the view shows 0–140.
        #expect(PanelLayout.scrollAnchor(row: 3, offset: 0, viewportHeight: viewport) == .bottom)
    }

    @Test func aRowAboveTheViewScrollsItToTheTop() {
        // Row 1 is 40–80; the view shows 50–190.
        #expect(PanelLayout.scrollAnchor(row: 1, offset: 50, viewportHeight: viewport) == .top)
    }
}
