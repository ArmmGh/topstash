import SwiftUI

/// Text colors and fonts for the notch panel. All panel text styles live here, next to `PanelLayout`.
///
/// The shape is black in light and dark mode, so these are fixed shades of white rather than the
/// system's semantic levels, whose primary is dimmer than the panel's white text.
enum PanelStyle {
    // MARK: - Colors

    /// Titles, the save card's text, and the "Saved" checkmark.
    static let primary = Color.white
    /// Text that supports the primary text: previews, counts, hints, and empty-list messages.
    static let secondary = Color.white.opacity(0.6)
    /// Text a step dimmer than primary: results that need no action, the access-denied card, the
    /// search view's status, and the "Show all" button.
    static let muted = Color.white.opacity(0.75)
    /// Text for a state with nothing to do: "Nothing to save".
    static let tertiary = Color.white.opacity(0.35)
    /// The "Open Settings" link.
    static let link = Color.white.opacity(0.85)
    /// The fill behind the save card and the search field.
    static let cardFill = Color.white.opacity(0.12)

    // MARK: - Fonts

    /// The save card's and the "Saved" checkmark's label.
    static let label = Font.system(size: 14, weight: .medium)
    /// The text typed in the search field.
    static let field = Font.system(size: 14)
    /// A note row's title.
    static let rowTitle = Font.system(size: 13, weight: .semibold)
    /// The save card's clipboard preview and empty-list messages.
    static let body = Font.system(size: 12)
    /// The "Show all" button.
    static let button = Font.system(size: 12, weight: .medium)
    /// Small secondary lines: a row's preview, the card's character count and hint.
    static let caption = Font.system(size: 11)
    /// The search view's status.
    static let captionEmphasized = Font.system(size: 11, weight: .medium)
    /// The save card's symbol.
    static let cardIcon = Font.system(size: 18, weight: .semibold)
    /// The "Saved" checkmark's symbol.
    static let savedIcon = Font.system(size: 26, weight: .semibold)
}
