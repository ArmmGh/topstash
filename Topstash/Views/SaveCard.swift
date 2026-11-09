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
                    icon("tray.and.arrow.down")
                    VStack(alignment: .leading, spacing: PanelLayout.cardLineSpacing) {
                        Text(Self.previewText(text))
                            .font(.system(size: 12))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                        Text(Self.characterCountText(characterCount))
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.55))
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
            .foregroundStyle(.white.opacity(0.75))
        case .alreadySaved:
            resultCard
                .foregroundStyle(.white.opacity(0.75))
        case .nothingToSave:
            resultCard
                .foregroundStyle(.white.opacity(0.35))
        case .saved:
            // `SaveCardSlot` shows its checkmark instead of a card.
            EmptyView()
        case .failed:
            resultCard
        }
    }

    /// A card with only the state's result label.
    @ViewBuilder
    private var resultCard: some View {
        if let result = state.result {
            card {
                icon(result.symbol)
                label(result.text)
            }
        }
    }

    /// `combiningAccessibility: false` keeps the settings link a separate accessibility element.
    private func card(
        combiningAccessibility: Bool = true,
        @ViewBuilder _ content: () -> some View
    ) -> some View {
        cardLayout(content)
            .foregroundStyle(.white)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: PanelLayout.cardCornerRadius))
            .contentShape(RoundedRectangle(cornerRadius: PanelLayout.cardCornerRadius))
            .accessibilityElement(children: combiningAccessibility ? .combine : .contain)
    }

    /// The card's content layout, without its background or hit shape.
    private func cardLayout(@ViewBuilder _ content: () -> some View) -> some View {
        HStack(alignment: .center, spacing: PanelLayout.cardIconSpacing) {
            content()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, PanelLayout.cardHorizontalPadding)
        .padding(.vertical, PanelLayout.cardVerticalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func readyWithoutPreviewContent(link: SettingsLink) -> some View {
        let hidesRest = link == .hitArea
        icon("tray.and.arrow.down")
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

    /// A secondary line with a link to the Paste privacy setting (#4).
    private func settingsHint(_ text: String, link: SettingsLink) -> some View {
        HStack(spacing: PanelLayout.inlineSpacing) {
            Text(text)
                .foregroundStyle(.white.opacity(0.55))
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
        .font(.system(size: 11))
        .lineLimit(1)
    }

    /// Invisible but laid out the same, for the `.hitArea` copy.
    private static func linkText(isVisible: Bool) -> some View {
        Text("Open Settings")
            .underline()
            .foregroundStyle(isVisible ? .white.opacity(0.85) : .clear)
    }

    private static func openPastePrivacySettings() {
        NSWorkspace.shared.open(Clipboard.pastePrivacySettingsURL)
    }

    private func icon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .semibold))
            .frame(width: PanelLayout.cardIconWidth)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
    }

    /// The text from its first non-blank line on, capped at `previewCharacterLimit`.
    static func previewText(_ text: String) -> String {
        guard let firstVisible = text.firstIndex(where: { !$0.isWhitespace }) else { return "" }
        let lineStart = text[..<firstVisible].lastIndex(where: \.isNewline).map { text.index(after: $0) }
            ?? text.startIndex
        return String(text[lineStart...].prefix(previewCharacterLimit))
    }

    /// "1 character", "1,234 characters".
    static func characterCountText(_ count: Int) -> String {
        "\(count.formatted()) \(count == 1 ? "character" : "characters")"
    }
}

/// The save card's place in the panel, with the save feedback (#11): on `.saved` the card flies up
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
                Image(systemName: SaveCardState.savedResult.symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .symbolEffect(.bounce, value: bounceTrigger)
                Text(SaveCardState.savedResult.text)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(.white)
            .opacity(isSaved ? 1 : 0)
            .accessibilityElement(children: .combine)
            .accessibilityHidden(!isSaved)
        }
        .frame(height: PanelLayout.saveCardHeight)
        .animation(isSaved ? (reduceMotion ? Motion.reduced : Motion.flyUp) : Motion.contentIn, value: isSaved)
    }
}

/// The shortcut's result in search mode (#10), where there's no card: the card's label, compact,
/// next to the search field.
struct SaveStatusBadge: View {
    let state: SaveCardState
    let bounceTrigger: Int

    var body: some View {
        if let result = state.result {
            HStack(spacing: PanelLayout.inlineSpacing) {
                Image(systemName: result.symbol)
                    .symbolEffect(.bounce, value: bounceTrigger)
                Text(result.text)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.75))
            .lineLimit(1)
            .fixedSize()
            .accessibilityElement(children: .combine)
        }
    }
}

extension SaveCardState {
    /// The label and symbol of a save's result, shared by the card, the checkmark, and the search
    /// view's status. `nil` for the states that aren't a result.
    fileprivate var result: (text: String, symbol: String)? {
        switch self {
        case .saved: Self.savedResult
        case .alreadySaved: ("Already saved", "checkmark")
        case .nothingToSave: ("Nothing to save", "tray")
        case .failed: ("Couldn't save", "exclamationmark.triangle")
        // Only the search view's status uses this; the card has its own `.accessDenied` layout.
        case .accessDenied: ("Can't read the clipboard", "hand.raised")
        case .preview, .readyWithoutPreview: nil
        }
    }

    fileprivate static let savedResult = (text: "Saved", symbol: "checkmark.circle.fill")
}

private extension View {
    /// `hidden()` when `isHidden`: invisible, still taking up its space, and not hit-testable.
    @ViewBuilder
    func hidden(_ isHidden: Bool) -> some View {
        if isHidden { hidden() } else { self }
    }
}
