import CoreGraphics
import Testing

@testable import Topstash

/// How much taller a peeked row is (`PanelLayout.peekExtraHeight`), and how that height reaches the
/// shape and the search scroll offset. A collapsed row is 40 pt: a 16 pt title, 2 pt, one 13 pt
/// preview line, and 9 pt of padding. A peek shows up to 12 lines in place of the preview, 14 pt
/// apart as SwiftUI draws 11 pt text, so a peek of one line is 1 pt taller than the preview.
@MainActor
struct PeekLayoutTests {
    @Test func aOneLinePeekIsOnePointTallerThanThePreview() {
        #expect(PanelLayout.peekExtraHeight(for: "one line") == 1)
    }

    @Test func anEmptyPeekLeavesTheRowAsItIs() {
        #expect(PanelLayout.peekExtraHeight(for: "") == 0)
    }

    @Test func eachMoreLineAddsFourteenPoints() {
        #expect(PanelLayout.peekExtraHeight(for: "one\ntwo\nthree") == 29)
    }

    @Test func longLinesWrapAtTheRowsTextWidth() {
        // Far wider than the row's 352 pt at 11 pt, so it wraps to more than one line.
        let extra = PanelLayout.peekExtraHeight(for: String(repeating: "wrap ", count: 40))

        #expect(extra > 1)
        #expect((extra - 1).truncatingRemainder(dividingBy: 14) == 0)
    }

    @Test func stopsAtTwelveLinesForA195PointRow() {
        let text = (1...40).map(String.init).joined(separator: "\n")

        #expect(PanelLayout.peekExtraHeight(for: text) == 155)
        #expect(PanelLayout.maxPeekExtraHeight == 155)
        #expect(PanelLayout.rowHeight + PanelLayout.maxPeekExtraHeight == 195)
    }

    // MARK: Scrolling to the first match

    /// Lines "1" to "40".
    let fortyLines = (1...40).map(String.init).joined(separator: "\n")

    func scrollOffset(toLine line: String, in text: String) -> CGFloat {
        PanelLayout.peekScrollOffset(showing: text.range(of: "\n\(line)\n")!.lowerBound, in: text)
    }

    @Test func aMatchInTheFirstTwelveLinesLeavesThePeekAtTheTop() {
        #expect(PanelLayout.peekScrollOffset(showing: fortyLines.startIndex, in: fortyLines) == 0)
        // The newline before "12" is on line 11.
        #expect(scrollOffset(toLine: "12", in: fortyLines) == 0)
    }

    @Test func aMatchFurtherDownScrollsItToTheSecondLine() {
        // The newline before "20" is on line 19: scrolled 17 lines of 14 pt, one line of context above it.
        #expect(Double(scrollOffset(toLine: "20", in: fortyLines)) == 238)
    }

    @Test func wrappedLinesCountTowardsTheMatchsLine() {
        // Wraps to more than one line, so line 20 is further down than in `fortyLines`.
        let text = String(repeating: "wrap ", count: 40) + "\n" + fortyLines

        #expect(Double(scrollOffset(toLine: "20", in: text)) > 238)
    }

    // MARK: Shape

    func makePanel(_ mode: PanelModel.Mode) -> PanelModel {
        let panel = PanelModel()
        panel.closedSize = CGSize(width: 185, height: 32)
        panel.headerHeight = 32
        panel.saveCard = .preview(text: "one\ntwo\nthree", characterCount: 13)
        panel.mode = mode
        return panel
    }

    @Test func aPeekGrowsTheOpenShapeByItsExtraHeight() {
        let size = PanelLayout.shapeSize(for: makePanel(.open), noteCount: 3, peekExtraHeight: 26)

        // 269 with three collapsed rows (`PanelShapeSizeTests`).
        #expect(Double(size.height) == 295)
    }

    @Test func aPeekGrowsTheSearchShapeUpToItsMaximum() {
        let grown = PanelLayout.shapeSize(for: makePanel(.search), noteCount: 12, resultCount: 4, peekExtraHeight: 26)
        let capped = PanelLayout.shapeSize(
            for: makePanel(.search), noteCount: 40, resultCount: 9, peekExtraHeight: 155)

        // 277 with four collapsed results (`PanelShapeSizeTests`).
        #expect(Double(grown.height) == 303)
        #expect(Double(capped.height) == 520)
    }

    @Test func theWindowFitsTheTallestPanelWithATwelveLinePeek() {
        let panel = makePanel(.open)
        panel.headerHeight = PanelLayout.maxHeaderHeight
        let tallest = PanelLayout.shapeSize(
            for: panel, noteCount: 5, peekExtraHeight: PanelLayout.maxPeekExtraHeight)

        #expect(Double(tallest.height) == 516)
        #expect(PanelLayout.windowSize.height >= tallest.height + PanelLayout.shadowPadding)
    }

    // MARK: Scrolling the search results

    /// Room for three and a half collapsed rows.
    let viewport: CGFloat = 140

    @Test func rowsBelowAPeekAreLowerByItsExtraHeight() {
        // Row 0 is peeked, 0–80; row 1 is 80–120, in view; row 2 is 120–160, so it scrolls by 20.
        #expect(
            PanelLayout.scrollOffset(
                showingRow: 1, peekedRow: 0, peekExtraHeight: 40, offset: 0, viewportHeight: viewport) == nil)
        #expect(
            PanelLayout.scrollOffset(
                showingRow: 2, peekedRow: 0, peekExtraHeight: 40, offset: 0, viewportHeight: viewport) == 20)
    }

    @Test func rowsAboveAPeekDoNotMove() {
        #expect(
            PanelLayout.scrollOffset(
                showingRow: 1, peekedRow: 3, peekExtraHeight: 100, offset: 50, viewportHeight: viewport) == 40)
    }

    @Test func aPeekedRowScrollsUntilItsBottomIsInView() {
        // Row 1 peeked by 40 is 40–120 in a view showing 0–100.
        #expect(
            PanelLayout.scrollOffset(
                showingRow: 1, peekedRow: 1, peekExtraHeight: 40, offset: 0, viewportHeight: 100) == 20)
    }

    @Test func aPeekedRowTallerThanTheViewScrollsToItsTop() {
        // Row 1 peeked by 155 is 40–235, taller than the 140 pt view.
        #expect(
            PanelLayout.scrollOffset(
                showingRow: 1, peekedRow: 1, peekExtraHeight: 155, offset: 0, viewportHeight: viewport) == 40)
    }
}
