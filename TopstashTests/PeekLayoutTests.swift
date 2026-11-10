import Foundation
import Testing

@testable import Topstash

/// How much taller a peeked row is (`PanelLayout.peekExtraHeight`), and how that height reaches the
/// shape and the search scroll offset. A collapsed row is 40 pt: a 16 pt title, 2 pt, one 13 pt
/// preview line, and 9 pt of padding. A peek shows up to 12 lines in place of the preview, 14 pt
/// apart as SwiftUI draws 11 pt text, so a peek of one line is 1 pt taller than the preview.
@MainActor
struct PeekLayoutTests {
    /// The extra height of a peek at `text`, as `PanelModel.togglePeek` works it out.
    func extraHeight(for text: String, matches: [Range<String.Index>] = []) -> CGFloat {
        NotePeek(
            note: URL(filePath: "/note.md"), text: text, lineCount: PanelLayout.peekLineCount(text, matches: matches)
        )
        .extraHeight
    }

    /// The longest run of "w" that fits on one line of a peek in `meta`'s regular weight.
    let fullLine: String = {
        var count = 1
        while PanelLayout.peekLineCount(String(repeating: "w", count: count + 1)) == 1 { count += 1 }
        return String(repeating: "w", count: count)
    }()

    @Test func aOneLinePeekIsOnePointTallerThanThePreview() {
        #expect(extraHeight(for: "one line") == 1)
    }

    @Test func anEmptyPeekLeavesTheRowAsItIs() {
        #expect(extraHeight(for: "") == 0)
    }

    @Test func eachMoreLineAddsFourteenPoints() {
        #expect(extraHeight(for: "one\ntwo\nthree") == 29)
    }

    @Test func longLinesWrapAtTheRowsTextWidth() {
        // Far wider than the row's 352 pt at 11 pt, so it wraps to more than one line.
        let extra = extraHeight(for: String(repeating: "wrap ", count: 40))

        #expect(extra > 1)
        #expect((extra - 1).truncatingRemainder(dividingBy: 14) == 0)
    }

    @Test func matchesAreMeasuredInTheirHeavierWeight() {
        // A full line in regular weight is wider than the row in `metaMatch`'s semibold, so it wraps.
        let text = fullLine
        let wholeLine = [text.startIndex..<text.endIndex]

        #expect(extraHeight(for: text) == 1)
        #expect(extraHeight(for: text, matches: wholeLine) == 15)
    }

    @Test func stopsAtTwelveLinesForA195PointRow() {
        let text = (1...40).map(String.init).joined(separator: "\n")

        #expect(extraHeight(for: text) == 155)
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

    @Test func matchesAboveTheFirstShownOneAreMeasuredInTheirHeavierWeight() {
        // Twelve full lines, each wrapping in semibold, then the forty: "20" is 12 lines further
        // down with every full line matched.
        let text = Array(repeating: fullLine, count: 12).joined(separator: "\n") + "\n" + fortyLines
        let fullLines = text.ranges(of: fullLine)
        let match = text.range(of: "\n20\n")!

        let regular = PanelLayout.peekScrollOffset(showing: match.lowerBound, in: text)
        let semibold = PanelLayout.peekScrollOffset(showing: match.lowerBound, in: text, matches: fullLines)

        #expect(Double(semibold - regular) == 12 * 14)
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
