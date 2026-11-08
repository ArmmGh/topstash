import CoreGraphics

/// Size constants for the notch panel. All sizes live here.
enum PanelLayout {
    /// The fixed window frame, big enough for the panel with a full recent list and for the search
    /// shape, plus shadow padding. It never changes or animates; only the SwiftUI content does.
    static let windowSize = CGSize(
        width: max(480, searchSize.width + 2 * shadowPadding),
        height: max(maxPanelHeight, searchSize.height) + shadowPadding
    )
    /// Room around the shape for the shadow drawn in SwiftUI (#11).
    static let shadowPadding: CGFloat = 30

    /// The width of the visible black shape. Its height follows the content.
    static let panelWidth: CGFloat = 380
    static let bottomCornerRadius: CGFloat = 20

    /// Space kept clear at the top of the shape for the hardware notch.
    static let notchClearance: CGFloat = 38
    static let contentPadding: CGFloat = 14

    static let cardCornerRadius: CGFloat = 12
    static let saveCardHeight: CGFloat = 64

    /// How many of the newest notes the panel lists under the save card.
    static let recentCount = 5
    static let rowHeight: CGFloat = 40
    static let rowSpacing: CGFloat = 2
    static let rowCornerRadius: CGFloat = 8
    /// Space between the save card and the recent list.
    static let sectionSpacing: CGFloat = 8

    /// The "Show all (N)" button under the recent list.
    static let showAllHeight: CGFloat = 28

    /// The shape's height with `recentCount` rows and the "Show all" button.
    static let maxPanelHeight: CGFloat = notchClearance + saveCardHeight + sectionSpacing
        + CGFloat(recentCount) * rowHeight + CGFloat(recentCount - 1) * rowSpacing
        + sectionSpacing + showAllHeight + contentPadding

    /// The shape in search mode: the search field above the scrollable list of every note.
    static let searchSize = CGSize(width: 400, height: 520)
    static let searchFieldHeight: CGFloat = 32

    /// Width of the invisible hover strip on screens without a notch.
    static let fallbackHoverWidth: CGFloat = 200
    /// Height of that strip when the screen's menu bar is hidden.
    static let hiddenMenuBarHoverHeight: CGFloat = 24

    /// How long the content takes to fade out before the window is ordered out.
    static let fadeDuration: Double = 0.2
}
