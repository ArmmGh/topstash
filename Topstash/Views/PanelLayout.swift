import AppKit

/// Size constants for the notch panel. All sizes live here.
enum PanelLayout {
    /// The fixed window frame, big enough for the panel with a full recent list and for the search
    /// shape, with their outward top corners, plus shadow padding. It never changes or animates;
    /// only the SwiftUI content does.
    static let windowSize = CGSize(
        width: panelWidth + 2 * (topCornerRadius + shadowPadding),
        height: max(maxPanelHeight + maxPeekExtraHeight, maxSearchHeight) + shadowPadding
    )
    /// Room around the shape for the shadow drawn in SwiftUI.
    static let shadowPadding: CGFloat = 30
    static let shadowRadius: CGFloat = 12
    static let shadowOffsetY: CGFloat = 6
    static let shadowOpacity: Double = 0.45

    /// The width of the visible black shape's body, without the outward top corners, in every open
    /// mode: switching between the list and search changes only the height.
    static let panelWidth: CGFloat = 400

    /// `NotchShape` radii while open. The outward top corners add `topCornerRadius` on each side.
    static let topCornerRadius: CGFloat = 15
    static let bottomCornerRadius: CGFloat = 20
    /// `NotchShape` radii while closed, when the shape hides behind the notch. No outward top
    /// corners, which would show beside the notch: they grow as the shape comes out of it.
    static let collapsedTopCornerRadius: CGFloat = 0
    static let collapsedBottomCornerRadius: CGFloat = 14
    /// How much narrower and shorter than the notch the closed shape is, so its edges hide behind
    /// the hardware notch on the first and last frames, and the panel seems to grow out of the notch.
    static let hiddenNotchInset: CGFloat = 4

    // MARK: - Header

    /// The header beside the notch is as tall as the notch, or the menu bar on screens without one,
    /// but never shorter than its button.
    static func headerHeight(forHoverAreaHeight hoverAreaHeight: CGFloat) -> CGFloat {
        max(hoverAreaHeight, headerButtonSize)
    }

    /// Taller than any notch or menu bar, for sizing the window, which never changes.
    static let maxHeaderHeight: CGFloat = 44
    /// The header's circular button: search in the list, close in search.
    static let headerButtonSize: CGFloat = 28
    /// Between the header's count and its button.
    static let headerSpacing: CGFloat = 8

    /// The width of each side of the header, `inset` from the shape's edge to the notch, so nothing
    /// in it sits under the notch. `notchWidth` is 0 on screens without one.
    static func headerSideWidth(notchWidth: CGFloat) -> CGFloat {
        (panelWidth - 2 * inset - notchWidth) / 2
    }

    // MARK: - Content

    /// The one inset of the 4 pt grid: from the shape's edge to the card and rows, and again inside
    /// each card and row, so every text edge and the card's icon sit `2 * inset` from the shape's edge.
    static let inset: CGFloat = 12

    static let cardCornerRadius: CGFloat = 12
    /// The height of a 13 pt line: the preview's and the card's labels.
    static let cardTextLineHeight: CGFloat = 16
    /// The height of the 11 pt hint line.
    static let cardHintLineHeight: CGFloat = 13
    /// The most lines of clipboard text the card previews.
    static let maxPreviewLines = 3
    /// The width the preview wraps at: the panel less both insets on each side, the icon, and its spacing.
    static let previewWidth: CGFloat = panelWidth - 4 * inset - cardIconWidth - cardIconSpacing

    /// The card fits its text, with `inset` above and below: the preview's lines and the hint, a
    /// label and a hint, or only a label. Known before layout, so the shape can animate to it.
    static func saveCardHeight(for state: SaveCardState) -> CGFloat {
        switch state {
        case .preview(let text, _): saveCardHeight(previewLines: previewLineCount(text))
        case .readyWithoutPreview, .accessDenied: saveCardHeight(previewLines: 1)
        case .alreadySaved, .concealed, .nothingToSave, .failed, .saved: compactSaveCardHeight
        }
    }

    private static func saveCardHeight(previewLines: Int) -> CGFloat {
        2 * inset + CGFloat(previewLines) * cardTextLineHeight + cardLineSpacing + cardHintLineHeight
    }

    /// The preview lines a card this tall was sized for: the inverse of `saveCardHeight(previewLines:)`.
    static func previewLines(inCardHeight height: CGFloat) -> Int {
        let lines = (height - saveCardHeight(previewLines: 0)) / cardTextLineHeight
        return min(max(Int(lines.rounded()), 1), maxPreviewLines)
    }

    /// How many lines, up to `maxPreviewLines`, the preview wraps to in the card.
    /// Measured with the preview's font and width, so the card's height is known before layout.
    static func previewLineCount(_ text: String) -> Int {
        let storage = NSTextStorage(string: text, attributes: [.font: NSFont.systemFont(ofSize: PanelStyle.bodySize)])
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: previewWidth, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.maximumNumberOfLines = maxPreviewLines
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        var lines = 0
        layoutManager.enumerateLineFragments(
            forGlyphRange: layoutManager.glyphRange(for: container)
        ) { _, _, _, _, _ in lines += 1 }
        return max(1, lines)
    }

    /// A card with only a label.
    static let compactSaveCardHeight: CGFloat = 2 * inset + cardTextLineHeight
    /// A card with three lines of preview, the tallest.
    static let maxSaveCardHeight: CGFloat = saveCardHeight(previewLines: maxPreviewLines)
    /// Between the card's icon and its text.
    static let cardIconSpacing: CGFloat = 12
    static let cardIconWidth: CGFloat = 20
    /// The card's symbol below the top of its text.
    static let cardIconTopOffset: CGFloat = 1
    /// Between the lines of the card's text.
    static let cardLineSpacing: CGFloat = 4
    /// Between the "Saved" checkmark and its label.
    static let savedCheckmarkSpacing: CGFloat = 8
    /// Between small items on one line: the card's hint and its settings link, the search status's
    /// symbol and label.
    static let inlineSpacing: CGFloat = 4

    /// How many of the newest notes the panel lists under the save card.
    static let recentCount = 5
    static let rowHeight: CGFloat = 40
    /// Rows touch; only the hovered one shows a fill.
    static let rowSpacing: CGFloat = 0
    /// `bottomCornerRadius - inset`, so a row's corners nest inside the shape's.
    static let rowCornerRadius: CGFloat = bottomCornerRadius - inset
    /// Between a row's title and preview.
    static let rowLineSpacing: CGFloat = 2
    /// Above a row's title and below its preview: what's left of `rowHeight` around the two lines.
    static let rowVerticalPadding: CGFloat =
        (rowHeight - cardTextLineHeight - rowLineSpacing - previewLineHeight) / 2
    /// Between a row's text and its age.
    static let rowAgeSpacing: CGFloat = 8
    /// The peek chevron's hit area, over the row's age and flush with its right edge.
    static let peekChevronSize: CGFloat = 20
    /// Between the header, the save card or search field, and the list.
    static let sectionSpacing: CGFloat = 8

    /// Where to scroll the search results so the row at `index` is fully in view: just far enough
    /// to bring it to the top or bottom edge, or `nil` when it's already in view. A row taller than
    /// the view is brought to the top. `offset` is how far the results are scrolled. This needs no
    /// layout: `NoteRow` fixes its height to `rowHeight`, or `rowHeight + peekExtraHeight` for the
    /// row at `peekedRow`, and nothing sits above the rows in the scroll view.
    static func scrollOffset(
        showingRow index: Int, peekedRow: Int? = nil, peekExtraHeight: CGFloat = 0, offset: CGFloat,
        viewportHeight: CGFloat
    ) -> CGFloat? {
        let shift = peekedRow.map { $0 < index } == true ? peekExtraHeight : 0
        let top = CGFloat(index) * (rowHeight + rowSpacing) + shift
        let bottom = top + rowHeight + (peekedRow == index ? peekExtraHeight : 0)
        if top < offset || bottom - top > viewportHeight { return top }
        if bottom > offset + viewportHeight { return bottom - viewportHeight }
        return nil
    }

    // MARK: - Peek

    /// The most lines a row's peek shows before it scrolls: a 195 pt row, which fits the window.
    static let maxPeekLines = 12
    /// The distance between lines of the 11 pt peek as SwiftUI draws them: a point more than
    /// `previewLineHeight`, which `NSLayoutManager` gives the same font.
    static let peekLineHeight: CGFloat = 14
    /// The height of a row's one 11 pt preview line, which the peek replaces.
    static let previewLineHeight: CGFloat = 13
    /// The width the peek wraps at: the row's text, from inset to inset inside the row.
    static let peekWidth: CGFloat = panelWidth - 4 * inset
    /// The peek of `maxPeekLines` lines.
    static let maxPeekExtraHeight: CGFloat = peekExtraHeight(lines: maxPeekLines)

    /// How much taller than `rowHeight` a row is while it peeks at `text`: the lines `text` wraps to,
    /// up to `maxPeekLines`, in place of the one preview line. Measured with the peek's font and
    /// width, so the shape can animate to the taller row before layout.
    static func peekExtraHeight(for text: String) -> CGFloat {
        peekExtraHeight(lines: peekLineCount(text))
    }

    /// A peek of this many lines in place of the preview line. With none, the row stays as it is.
    static func peekExtraHeight(lines: Int) -> CGFloat {
        lines == 0 ? 0 : peekBodyHeight(lines: lines) - previewLineHeight
    }

    /// The height of a peek's text that shows this many lines; longer text scrolls inside it.
    static func peekBodyHeight(lines: Int) -> CGFloat {
        CGFloat(lines) * peekLineHeight
    }

    /// How many lines, up to `maxPeekLines`, `text` wraps to in a row's peek. 0 when it's empty.
    static func peekLineCount(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        let storage = NSTextStorage(
            string: text,
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: PanelStyle.metaSize, weight: .regular)])
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: peekWidth, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.maximumNumberOfLines = maxPeekLines
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        var lines = 0
        layoutManager.enumerateLineFragments(
            forGlyphRange: layoutManager.glyphRange(for: container)
        ) { _, _, _, _, _ in lines += 1 }
        return min(max(1, lines), maxPeekLines)
    }

    /// The ring around the keyboard-selected search result.
    static let selectionRingWidth: CGFloat = 1.5
    /// Between the key hints under the search results.
    static let keyHintSpacing: CGFloat = 16
    /// Between a key hint's symbol and its label.
    static let keyHintLabelSpacing: CGFloat = 4
    /// The height of the 11 pt key hints line under the search results.
    static let keyHintsHeight: CGFloat = 13

    /// The shape's height with the tallest header and card and `recentCount` rows.
    static let maxPanelHeight: CGFloat = recentPanelHeight(
        rowCount: recentCount, saveCardHeight: maxSaveCardHeight, headerHeight: maxHeaderHeight)

    /// The shape's height with this many recent rows under a header and card this tall, one of the
    /// rows taller by `peekExtraHeight` while it peeks. With none, "No notes yet" takes one row's
    /// height. Matches `PanelView`'s recent content, so the shape can animate to it before the
    /// content is laid out.
    static func recentPanelHeight(
        rowCount: Int, saveCardHeight: CGFloat, headerHeight: CGFloat, peekExtraHeight: CGFloat = 0
    ) -> CGFloat {
        let listHeight =
            rowCount == 0
            ? rowHeight
            : CGFloat(rowCount) * rowHeight + CGFloat(rowCount - 1) * rowSpacing + peekExtraHeight
        return headerHeight + sectionSpacing + saveCardHeight + sectionSpacing + listHeight + inset
    }

    /// The size of the shape's body (without the outward top corners) in the panel's mode: closed,
    /// just inside the notch (or the hover strip with no height, on screens without one); open, the header, the card,
    /// and up to `recentCount` of the store's `noteCount` notes; search, its `resultCount` results.
    /// In both, a row that peeks adds `peekExtraHeight`.
    @MainActor static func shapeSize(
        for panel: PanelModel, noteCount: Int, resultCount: Int = 0, peekExtraHeight: CGFloat = 0
    ) -> CGSize {
        switch panel.mode {
        case .closed:
            // Without a notch the closed shape has no height and draws nothing.
            panel.closedSize.height > 0
                ? CGSize(
                    width: panel.closedSize.width - hiddenNotchInset,
                    height: panel.closedSize.height - hiddenNotchInset)
                : panel.closedSize
        case .open:
            CGSize(
                width: panelWidth,
                height: recentPanelHeight(
                    rowCount: min(noteCount, recentCount), saveCardHeight: panel.saveCardHeight,
                    headerHeight: panel.headerHeight, peekExtraHeight: peekExtraHeight))
        case .search:
            CGSize(
                width: panelWidth,
                height: searchPanelHeight(
                    resultCount: resultCount, headerHeight: panel.headerHeight, peekExtraHeight: peekExtraHeight))
        case .feedback:
            // Only the save card, under the header's band.
            CGSize(
                width: panelWidth,
                height: panel.headerHeight + sectionSpacing + panel.saveCardHeight + inset)
        }
    }

    /// Moves the center of a saved card this tall, under a header this tall, up to the middle of
    /// the header: the notch.
    static func saveCardFlyUpOffset(cardHeight: CGFloat, headerHeight: CGFloat) -> CGFloat {
        -(headerHeight / 2 + sectionSpacing + cardHeight / 2)
    }

    /// The shape's height in search with this many results under a header this tall: the header,
    /// the search field, the rows (or "No matches" in one row's height), and the key hints when
    /// there are results. Matches `SearchView`'s layout, so the shape can animate to it before the
    /// content is laid out. One result is taller by `peekExtraHeight` while it peeks. Stops at
    /// `maxSearchHeight`, where the results scroll.
    static func searchPanelHeight(resultCount: Int, headerHeight: CGFloat, peekExtraHeight: CGFloat = 0) -> CGFloat {
        let listHeight =
            resultCount == 0
            ? rowHeight
            : CGFloat(resultCount) * rowHeight + CGFloat(resultCount - 1) * rowSpacing + peekExtraHeight
        let hintsHeight = resultCount == 0 ? 0 : sectionSpacing + keyHintsHeight
        let height =
            headerHeight + sectionSpacing + searchFieldHeight + sectionSpacing + listHeight + hintsHeight + inset
        return min(height, maxSearchHeight)
    }

    /// The tallest the search shape gets; more results scroll.
    static let maxSearchHeight: CGFloat = 520
    static let searchFieldHeight: CGFloat = 36
    /// Smaller than the card's 12, for the shorter field.
    static let searchFieldCornerRadius: CGFloat = 10
    /// Between the search field's symbol, text, the shortcut's status, and "esc".
    static let searchFieldSpacing: CGFloat = 8

    /// Width of the invisible hover strip on screens without a notch.
    static let fallbackHoverWidth: CGFloat = 200
    /// Height of that strip when the screen's menu bar is hidden.
    static let hiddenMenuBarHoverHeight: CGFloat = 24
}
