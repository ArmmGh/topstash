import AppKit
import SwiftUI

/// The card that saves the clipboard text as a note. Only `.preview` and `.readyWithoutPreview` are buttons.
struct SaveCard: View {
    let state: SaveCardState
    let action: () -> Void

    /// Characters handed to `Text` for the preview. Three lines need far fewer; the cap keeps
    /// a huge clipboard from being laid out on every hover.
    private static let previewCharacterLimit = 600

    var body: some View {
        switch state {
        case .preview(let text, let characterCount):
            Button(action: action) {
                card {
                    icon(Self.saveSymbol)
                    VStack(alignment: .leading, spacing: PanelLayout.cardLineSpacing) {
                        // Already cut to its start by `previewText(_:)` when the state was set.
                        Text(text)
                            .font(PanelStyle.body)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                        Text(Self.saveHintText(characterCount))
                            .font(PanelStyle.meta)
                            .foregroundStyle(PanelStyle.secondary)
                    }
                }
            }
            .buttonStyle(PressDipButtonStyle())
        case .readyWithoutPreview:
            Button(action: action) {
                card(combiningAccessibility: false) {
                    readyWithoutPreviewContent(link: .text)
                }
            }
            .buttonStyle(PressDipButtonStyle())
            // The link is laid over the card instead of being a button inside the card's button,
            // where macOS doesn't guarantee which button gets the click: saving would read the
            // clipboard and show the alert the user was about to avoid. This copy has the same
            // layout with everything but the link hidden, so clicks elsewhere still reach the card.
            .overlay {
                cardLayout { readyWithoutPreviewContent(link: .hitArea) }
            }
        case .accessDenied:
            card(combiningAccessibility: false) {
                icon("hand.raised")
                VStack(alignment: .leading, spacing: PanelLayout.cardLineSpacing) {
                    label("Topstash can't read the clipboard")
                    settingsHint("Allow paste access to save from here", link: .button)
                }
            }
            .foregroundStyle(PanelStyle.secondary)
        case .alreadySaved:
            resultCard(.alreadySaved)
                .foregroundStyle(PanelStyle.secondary)
        case .nothingToSave:
            resultCard(.nothingToSave)
                .foregroundStyle(PanelStyle.tertiary)
        case .saved:
            // `SaveCardSlot` shows its checkmark instead of a card.
            EmptyView()
        case .failed:
            resultCard(.failed)
        }
    }

    /// A card with only the result's label.
    private func resultCard(_ result: ClipboardSaveResult) -> some View {
        card {
            icon(result.label.symbol)
            label(result.label.text)
        }
    }

    /// `combiningAccessibility: false` keeps the settings link a separate accessibility element.
    private func card(
        combiningAccessibility: Bool = true,
        @ViewBuilder _ content: () -> some View
    ) -> some View {
        cardLayout(content)
            .foregroundStyle(PanelStyle.primary)
            .cardBackground()
            .contentShape(RoundedRectangle(cornerRadius: PanelLayout.cardCornerRadius))
            .accessibilityElement(children: combiningAccessibility ? .combine : .contain)
    }

    /// The card's content layout, without its background or hit shape.
    private func cardLayout(@ViewBuilder _ content: () -> some View) -> some View {
        // The icon sits on the first line of text, whether the card has one line or four.
        HStack(alignment: .firstTextBaseline, spacing: PanelLayout.cardIconSpacing) {
            content()
            Spacer(minLength: 0)
        }
        .padding(PanelLayout.inset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func readyWithoutPreviewContent(link: SettingsLink) -> some View {
        let hidesRest = link == .hitArea
        icon(Self.saveSymbol)
            .hidden(hidesRest)
        VStack(alignment: .leading, spacing: PanelLayout.cardLineSpacing) {
            label("Text ready to save")
                .hidden(hidesRest)
            settingsHint("Allow paste access to see a preview", link: link)
        }
    }

    /// How `settingsHint` shows its "Open Settings" link.
    private enum SettingsLink {
        /// A button, in a card that isn't one.
        case button
        /// Only the link's look, inside the card's button; a `.hitArea` copy laid over it takes the clicks.
        case text
        /// An invisible button over a `.text` link, with the rest of the line hidden.
        case hitArea
    }

    /// A secondary line with a link to the Paste privacy setting.
    private func settingsHint(_ text: String, link: SettingsLink) -> some View {
        HStack(spacing: PanelLayout.inlineSpacing) {
            Text(text)
                .foregroundStyle(PanelStyle.secondary)
                .hidden(link == .hitArea)
            switch link {
            case .button:
                Button(action: Self.openPastePrivacySettings) { Self.linkText(isVisible: true) }
                    .buttonStyle(.plain)
            case .text:
                Self.linkText(isVisible: true)
                    .accessibilityHidden(true)
            case .hitArea:
                Button(action: Self.openPastePrivacySettings) {
                    Self.linkText(isVisible: false)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open Settings")
            }
        }
        .font(PanelStyle.meta)
        .lineLimit(1)
    }

    /// Invisible but laid out the same, for the `.hitArea` copy.
    private static func linkText(isVisible: Bool) -> some View {
        Text("Open Settings")
            .underline()
            .foregroundStyle(PanelStyle.primary)
            .opacity(isVisible ? 1 : 0)
    }

    private static func openPastePrivacySettings() {
        NSWorkspace.shared.open(SystemClipboard.pastePrivacySettingsURL)
    }

    /// Sized from the `title` font beside it, a scale up.
    private func icon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(PanelStyle.title)
            .imageScale(.large)
            .frame(width: PanelLayout.cardIconWidth)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(PanelStyle.title)
    }

    /// The text from its first non-blank line on, capped at `previewCharacterLimit`.
    static func previewText(_ text: String) -> String {
        guard let firstVisible = text.firstIndex(where: { !$0.isWhitespace }) else { return "" }
        let lineStart =
            text[..<firstVisible].lastIndex(where: \.isNewline).map { text.index(after: $0) }
            ?? text.startIndex
        return String(text[lineStart...].prefix(previewCharacterLimit))
    }

    /// The arrow out of the tray: the clipboard text going up into the notch. Also the menu bar icon.
    static let saveSymbol = "tray.and.arrow.up"

    /// "Click to save · 1 character", "Click to save · 1,234 characters".
    static func saveHintText(_ count: Int, locale: Locale = .current) -> String {
        "Click to save · \(count.formatted(.number.locale(locale))) \(count == 1 ? "character" : "characters")"
    }
}

/// The save card's place in the panel, with the save feedback: on `.saved` the card flies up
/// into the notch while a checkmark bounces in its place, then the card returns with the next state.
/// `AppModel` fires the haptic and `PanelView` the notch's gulp. Reduce Motion cross-fades instead.
struct SaveCardSlot: View {
    let panel: PanelModel
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isSaved: Bool { panel.saveCard == .saved }
    private var bounceTrigger: Int { reduceMotion ? 0 : panel.saveCount }

    var body: some View {
        ZStack {
            if !isSaved {
                SaveCard(state: panel.saveCard, action: action)
                    .transition(Motion.saveCard(reduceMotion: reduceMotion))
            }
            // Always in the hierarchy, so the bounce plays when `saveCount` changes.
            HStack(spacing: PanelLayout.savedCheckmarkSpacing) {
                Image(systemName: ClipboardSaveResult.savedSymbol)
                    .font(PanelStyle.savedIcon)
                    .symbolEffect(.bounce, value: bounceTrigger)
                Text(ClipboardSaveResult.savedText)
                    .font(PanelStyle.title)
            }
            .foregroundStyle(PanelStyle.primary)
            .opacity(isSaved ? 1 : 0)
            .accessibilityElement(children: .combine)
            .accessibilityHidden(!isSaved)
        }
        .frame(height: PanelLayout.saveCardHeight)
        .animation(isSaved ? (reduceMotion ? Motion.reduced : Motion.flyUp) : Motion.contentIn, value: isSaved)
    }
}

/// The shortcut's result in search mode, where there's no card: the card's label, compact,
/// next to the search field.
struct SaveStatusBadge: View {
    let result: ClipboardSaveResult
    /// 0 with Reduce Motion, otherwise `saveCount`.
    let bounceTrigger: Int

    /// Bumped when the badge appears showing a new save, and on every save while it's shown. The
    /// badge is inserted in the same update that bumps `saveCount`, so a `symbolEffect` keyed on
    /// `bounceTrigger` alone would see no change for the first save.
    @State private var bounces = 0

    var body: some View {
        HStack(spacing: PanelLayout.inlineSpacing) {
            Image(systemName: result.label.symbol)
                .symbolEffect(.bounce, value: bounces)
                .task {
                    if case .saved = result, bounceTrigger != 0 { bounces += 1 }
                }
                .onChange(of: bounceTrigger) { bounces += 1 }
            Text(result.label.text)
        }
        .font(PanelStyle.meta)
        .foregroundStyle(PanelStyle.secondary)
        .lineLimit(1)
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}

extension ClipboardSaveResult {
    /// The result's label and the SF Symbol shown with it, shared by the card, the checkmark, and
    /// the search view's status.
    fileprivate var label: (text: String, symbol: String) {
        switch self {
        case .saved: (Self.savedText, Self.savedSymbol)
        case .alreadySaved: ("Already saved", "checkmark")
        case .nothingToSave: ("Nothing to save", "tray")
        case .failed: ("Couldn't save", "exclamationmark.triangle")
        // Only the search view's status uses this; the card has its own `.accessDenied` layout.
        case .accessDenied: ("Can't read the clipboard", "hand.raised")
        }
    }

    /// The checkmark's label and symbol, for `SaveCardSlot`, which has no result at hand.
    fileprivate static let savedText = "Saved"
    fileprivate static let savedSymbol = "checkmark.circle.fill"
}

extension View {
    /// The fill shared by the save card and the search field.
    func cardBackground() -> some View {
        background(PanelStyle.surfaceFill, in: RoundedRectangle(cornerRadius: PanelLayout.cardCornerRadius))
    }

    /// `hidden()` when `isHidden`: invisible, still taking up its space, and not hit-testable.
    @ViewBuilder
    fileprivate func hidden(_ isHidden: Bool) -> some View {
        if isHidden { hidden() } else { self }
    }
}
