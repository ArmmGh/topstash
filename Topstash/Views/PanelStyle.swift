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
    /// Behind the save card and the search field. Matches `systemFill` in dark mode.
    static let surfaceFill = PanelColor(standard: 0.10, increased: 0.18)

    // MARK: - Fonts

    /// Row titles, the card's labels, "Saved", and buttons.
    static let title = Font.system(size: 13, weight: .medium)
    /// The clipboard preview, the search field, and empty-list messages.
    static let body = Font.system(size: 13)
    /// Small lines: row previews, ages, counts, and hints. Digits are monospaced so counts don't jitter.
    static let meta = Font.system(size: 11).monospacedDigit()
    /// The "Saved" checkmark, the one symbol larger than the text beside it.
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
        Color.white.opacity(environment.colorSchemeContrast == .increased ? increased : standard)
    }
}
