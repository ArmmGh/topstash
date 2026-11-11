import SwiftUI

/// Text colors, fills, and fonts for the notch panel: the design system from docs/SPEC.md, "Visual Design".
/// All panel text styles live here, next to `PanelLayout`.
///
/// The shape is black in light and dark mode, so the colors are fixed shades of white rather than
/// the system's semantic levels, whose primary is dimmer than the panel's white text. Each level steps
/// up when Increase Contrast is on.
enum PanelStyle {
    // MARK: - Text

    /// Titles, the save card's text, and the "Saved" checkmark.
    static let primary = PanelColor(standard: 1, increased: 1)
    /// Text that supports the primary text: previews, hints, empty-list messages, and the card for a
    /// state the user can't act on.
    static let secondary = PanelColor(standard: 0.6, increased: 0.8)
    /// The least important text: ages, and the card for a state with nothing to do. 0.5 is the
    /// floor: lower fails WCAG AA for 11 pt text on black.
    static let tertiary = PanelColor(standard: 0.5, increased: 0.7)

    // MARK: - Fills

    /// Behind a row while the pointer is over it.
    static let hoverFill = PanelColor(standard: 0.06, increased: 0.12)
    /// Behind the save card, the search field, and the header's button. Matches `systemFill` in dark mode.
    static let surfaceFill = PanelColor(standard: 0.10, increased: 0.18)
    /// The ring around the keyboard-selected search result, on `hoverFill`. A ring, not a brighter
    /// fill, so the selection clears WCAG's 3:1 for state indicators.
    static let selectionRing = secondary

    // MARK: - Fonts

    /// Row titles, the header's title, the card's labels, and "Saved".
    static let title = Font.system(size: 13, weight: .medium)
    /// The clipboard preview, the search field, and empty-list messages.
    static let body = Font.system(size: bodySize)
    /// `body`'s size, for measuring the preview's lines (`PanelLayout.previewLineCount`).
    static let bodySize: CGFloat = 13
    /// Small lines: row previews, ages, counts, and hints. Digits are monospaced so counts don't jitter.
    static let meta = Font.system(size: metaSize).monospacedDigit()
    /// `meta`'s size, for measuring a row's peek (`PanelLayout.peekLineCount`).
    static let metaSize: CGFloat = 11
    /// The keys in the search's key hints ("⏎", "↑↓"), a step above their `meta` labels.
    static let metaKey = Font.system(size: metaSize, weight: .medium)
    /// The query's words in a search result's preview, a weight above `meta` so a match stands out by
    /// weight, not only by its primary color. `PanelLayout.peekLayout` measures a peek's matches in
    /// the same weight.
    static let metaMatch = Font.system(size: metaSize, weight: .semibold).monospacedDigit()
    /// The chevron that replaces a hovered row's age, a weight above it so the small glyph reads.
    static let peekChevron = Font.system(size: 10, weight: .semibold)
    /// The save card's symbol: the system's Title 3 (15 pt), a step above the 13 pt text beside it,
    /// as in the prototype, so it reads as the card's icon rather than a glyph in the text.
    static let cardIcon = Font.title3.weight(.medium)
    /// The header button's symbol, small inside its 28 pt circle.
    static let headerIcon = Font.system(size: 12, weight: .semibold)
    /// The search field's magnifier, the weight of the title text.
    static let searchIcon = Font.system(size: 13, weight: .medium)
    /// The "Saved" checkmark, the one symbol much larger than the text beside it.
    static let savedIcon = Font.system(size: 22, weight: .semibold)

    // MARK: - Symbols

    /// The arrow out of the tray: the clipboard text going up into the notch. On the save card and
    /// in the menu bar.
    static let saveSymbol = "tray.and.arrow.up"
}

/// White at an opacity that steps up when Increase Contrast is on.
struct PanelColor: ShapeStyle {
    let standard: Double
    let increased: Double

    func resolve(in environment: EnvironmentValues) -> Color {
        color(contrast: environment.colorSchemeContrast)
    }

    /// For places that take a `Color` rather than a style, such as an `AttributedString` run.
    func color(contrast: ColorSchemeContrast) -> Color {
        Color.white.opacity(contrast == .increased ? increased : standard)
    }
}
