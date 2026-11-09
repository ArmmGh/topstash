import AppKit

/// Size constants for the notch panel. All sizes live here.
enum PanelLayout {
    /// The fixed window frame, big enough for the panel with a full recent list and for the search
    /// shape, with their outward top corners, plus shadow padding. It never changes or animates;
    /// only the SwiftUI content does.
    static let windowSize = CGSize(
        width: max(panelWidth, searchSize.width) + 2 * (topCornerRadius + shadowPadding),
        height: max(maxPanelHeight, searchSize.height) + shadowPadding
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
    /// `NotchShape` radii while closed, when the shape is the size of the hover area (the notch).
    static let collapsedTopCornerRadius: CGFloat = 6
    static let collapsedBottomCornerRadius: CGFloat = 14

    /// Space kept clear at the top of the shape for the hardware notch.
    static let notchClearance: CGFloat = 38
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
        case .alreadySaved, .nothingToSave, .failed, .saved: compactSaveCardHeight
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
    /// Between a row's text and its age.
    static let rowAgeSpacing: CGFloat = 8
    /// Space between the save card and the recent list.
    static let sectionSpacing: CGFloat = 8

    /// The "Show all (N)" button under the recent list.
    static let showAllHeight: CGFloat = 28

    /// The shape's height with the tallest card, `recentCount` rows, and the "Show all" button.
    static let maxPanelHeight: CGFloat = recentPanelHeight(rowCount: recentCount, saveCardHeight: maxSaveCardHeight)

    /// The shape's height with this many recent rows under a card this tall. With none, "No notes yet"
    /// takes one row's height. Matches `PanelView`'s recent content, so the shape can animate to it
    /// before the content is laid out.
    static func recentPanelHeight(rowCount: Int, saveCardHeight: CGFloat) -> CGFloat {
        let listHeight =
            rowCount == 0
            ? rowHeight
            : CGFloat(rowCount) * rowHeight + CGFloat(rowCount - 1) * rowSpacing
        return notchClearance + saveCardHeight + sectionSpacing + listHeight
            + sectionSpacing + showAllHeight + inset
    }

    /// The size of the shape's body (without the outward top corners) in `mode`. `closedSize` is the
    /// notch's size (or the hover strip's, on screens without one); `noteCount` is how many notes
    /// the store holds, of which the open panel lists up to `recentCount`; `saveCardHeight` is
    /// `PanelModel.saveCardHeight`.
    static func shapeSize(
        for mode: PanelModel.Mode, closedSize: CGSize, noteCount: Int, saveCardHeight: CGFloat
    ) -> CGSize {
        switch mode {
        case .closed:
            closedSize
        case .open:
            CGSize(
                width: panelWidth,
                height: recentPanelHeight(rowCount: min(noteCount, recentCount), saveCardHeight: saveCardHeight))
        case .search:
            searchSize
        case .feedback:
            // Only the save card.
            CGSize(width: panelWidth, height: notchClearance + saveCardHeight + inset)
        }
    }

    /// Moves the center of a saved card this tall from its slot up to the middle of the notch clearance.
    static func saveCardFlyUpOffset(cardHeight: CGFloat) -> CGFloat {
        -(notchClearance + cardHeight) / 2
    }

    /// The shape in search mode: the search field above the scrollable list of every note.
    static let searchSize = CGSize(width: panelWidth, height: 520)
    static let searchFieldHeight: CGFloat = 36
    /// Smaller than the card's 12, for the shorter field.
    static let searchFieldCornerRadius: CGFloat = 10
    /// Between the search field's text and the shortcut's status.
    static let searchStatusSpacing: CGFloat = 8

    /// Width of the invisible hover strip on screens without a notch.
    static let fallbackHoverWidth: CGFloat = 200
    /// Height of that strip when the screen's menu bar is hidden.
    static let hiddenMenuBarHoverHeight: CGFloat = 24
}
