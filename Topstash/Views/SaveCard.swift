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
                    VStack(alignment: .leading, spacing: 4) {
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
            .buttonStyle(.plain)
        case .readyWithoutPreview:
            Button(action: action) {
                card(combiningAccessibility: false) {
                    icon("tray.and.arrow.down")
                    VStack(alignment: .leading, spacing: 4) {
                        label("Text ready to save")
                        settingsHint("Allow paste access to see a preview")
                    }
                }
            }
            .buttonStyle(.plain)
        case .accessDenied:
            card(combiningAccessibility: false) {
                icon("hand.raised")
                VStack(alignment: .leading, spacing: 4) {
                    label("Topstash can't read the clipboard")
                    settingsHint("Allow paste access to save from here")
                }
            }
            .foregroundStyle(.white.opacity(0.75))
        case .alreadySaved:
            card {
                icon("checkmark")
                label("Already saved")
            }
            .foregroundStyle(.white.opacity(0.75))
        case .nothingToSave:
            card {
                icon("tray")
                label("Nothing to save")
            }
            .foregroundStyle(.white.opacity(0.35))
        case .saved:
            card {
                icon("checkmark.circle.fill")
                label("Saved")
            }
        case .failed:
            card {
                icon("exclamationmark.triangle")
                label("Couldn't save")
            }
        }
    }

    /// `combiningAccessibility: false` keeps the settings link a separate accessibility element.
    private func card(
        combiningAccessibility: Bool = true,
        @ViewBuilder _ content: () -> some View
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            content()
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: PanelLayout.cardCornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: PanelLayout.cardCornerRadius))
        .accessibilityElement(children: combiningAccessibility ? .combine : .contain)
    }

    /// A secondary line with a link to the Paste privacy setting (#4).
    private func settingsHint(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .foregroundStyle(.white.opacity(0.55))
            Button("Open Settings") {
                NSWorkspace.shared.open(Clipboard.pastePrivacySettingsURL)
            }
            .buttonStyle(.plain)
            .underline()
            .foregroundStyle(.white.opacity(0.85))
        }
        .font(.system(size: 11))
        .lineLimit(1)
    }

    private func icon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .semibold))
            .frame(width: 24)
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
