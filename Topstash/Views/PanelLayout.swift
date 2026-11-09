import CoreGraphics

/// Size constants for the notch panel. All sizes live here.
enum PanelLayout {
    /// The fixed window frame, big enough for the panel with a full recent list and for the search
    /// shape, with their outward top corners, plus shadow padding. It never changes or animates;
    /// only the SwiftUI content does.
    static let windowSize = CGSize(
        width: max(panelWidth, searchSize.width) + 2 * (topCornerRadius + shadowPadding),
        height: max(maxPanelHeight, searchSize.height) + shadowPadding
    )
    /// Room around the shape for the shadow drawn in SwiftUI (#11).
    static let shadowPadding: CGFloat = 30
    static let shadowRadius: CGFloat = 12
    static let shadowOffsetY: CGFloat = 6
    static let shadowOpacity: Double = 0.45

    /// The width of the visible black shape's body, without the outward top corners.
    /// Its height follows the number of recent rows.
    static let panelWidth: CGFloat = 380

    /// `NotchShape` radii while open (#11). The outward top corners add `topCornerRadius` on each side.
    static let topCornerRadius: CGFloat = 15
    static let bottomCornerRadius: CGFloat = 20
    /// `NotchShape` radii while closed, when the shape is the size of the hover area (the notch).
    static let collapsedTopCornerRadius: CGFloat = 6
    static let collapsedBottomCornerRadius: CGFloat = 14

    /// Space kept clear at the top of the shape for the hardware notch.
    static let notchClearance: CGFloat = 38
    static let contentPadding: CGFloat = 14

    static let cardCornerRadius: CGFloat = 12
    /// Fits three preview lines plus the character count.
    static let saveCardHeight: CGFloat = 84
    static let cardHorizontalPadding: CGFloat = 14
    static let cardVerticalPadding: CGFloat = 10
    /// Between the card's icon and its text.
    static let cardIconSpacing: CGFloat = 10
    static let cardIconWidth: CGFloat = 24
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
    static let rowSpacing: CGFloat = 2
    static let rowCornerRadius: CGFloat = 8
    /// Between a row's title and preview.
    static let rowLineSpacing: CGFloat = 2
    static let rowHorizontalPadding: CGFloat = 10
    /// Space between the save card and the recent list.
    static let sectionSpacing: CGFloat = 8

    /// The "Show all (N)" button under the recent list.
    static let showAllHeight: CGFloat = 28

    /// The shape's height with `recentCount` rows and the "Show all" button.
    static let maxPanelHeight: CGFloat = recentPanelHeight(rowCount: recentCount)

    /// The shape's height with this many recent rows. With none, "No notes yet" takes one row's height.
    /// Matches `PanelView`'s recent content, so the shape can animate to it before the content is laid out.
    static func recentPanelHeight(rowCount: Int) -> CGFloat {
        let listHeight = rowCount == 0
            ? rowHeight
            : CGFloat(rowCount) * rowHeight + CGFloat(rowCount - 1) * rowSpacing
        return notchClearance + saveCardHeight + sectionSpacing + listHeight
            + sectionSpacing + showAllHeight + contentPadding
    }

    /// The size of the shape's body (without the outward top corners) in `mode`. `closedSize` is the
    /// notch's size (or the hover strip's, on screens without one); `noteCount` is how many notes
    /// the store holds, of which the open panel lists up to `recentCount`.
    static func shapeSize(for mode: PanelModel.Mode, closedSize: CGSize, noteCount: Int) -> CGSize {
        switch mode {
        case .closed:
            closedSize
        case .open:
            CGSize(width: panelWidth, height: recentPanelHeight(rowCount: min(noteCount, recentCount)))
        case .search:
            searchSize
        case .feedback:
            CGSize(width: panelWidth, height: feedbackPanelHeight)
        }
    }

    /// The shape's height in the shortcut's feedback (#10): only the save card.
    static let feedbackPanelHeight: CGFloat = notchClearance + saveCardHeight + contentPadding

    /// Moves the saved card's center from its slot up to the middle of the notch clearance (#11).
    static let saveCardFlyUpOffset: CGFloat = -(notchClearance + saveCardHeight) / 2

    /// The shape in search mode: the search field above the scrollable list of every note.
    static let searchSize = CGSize(width: 400, height: 520)
    static let searchFieldHeight: CGFloat = 32
    static let searchFieldHorizontalPadding: CGFloat = 12
    /// Between the search field's text and the shortcut's status (#10).
    static let searchStatusSpacing: CGFloat = 8

    /// Width of the invisible hover strip on screens without a notch.
    static let fallbackHoverWidth: CGFloat = 200
    /// Height of that strip when the screen's menu bar is hidden.
    static let hiddenMenuBarHoverHeight: CGFloat = 24
}
