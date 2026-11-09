import SwiftUI

/// The band beside the notch: the mode's title on the left; on the right, the note count and a
/// circular button (search in the list, close in search). Each side stops at the notch.
struct PanelHeader: View {
    let title: LocalizedStringKey
    let count: String
    /// What VoiceOver reads for the count: "12 notes", "4 of 12 notes match".
    let countLabel: String
    let buttonSymbol: String
    let buttonLabel: LocalizedStringKey
    let panel: PanelModel
    let action: () -> Void

    var body: some View {
        let sideWidth = PanelLayout.headerSideWidth(notchWidth: panel.notchWidth)
        HStack(spacing: 0) {
            Text(title)
                .font(PanelStyle.title)
                .foregroundStyle(PanelStyle.secondary)
                .frame(width: sideWidth, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            HStack(spacing: PanelLayout.headerSpacing) {
                Text(count)
                    .font(PanelStyle.meta)
                    .foregroundStyle(PanelStyle.tertiary)
                    .accessibilityLabel(countLabel)
                Button(action: action) {
                    Image(systemName: buttonSymbol)
                        .font(PanelStyle.headerIcon)
                        .foregroundStyle(PanelStyle.secondary)
                        .frame(width: PanelLayout.headerButtonSize, height: PanelLayout.headerButtonSize)
                        .background(PanelStyle.surfaceFill, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(buttonLabel)
            }
            .frame(width: sideWidth, alignment: .trailing)
        }
        .lineLimit(1)
        .padding(.horizontal, PanelLayout.inset)
        .frame(height: panel.headerHeight)
    }

    /// "12" notes in the list; "4 of 12" matches in search. A long count truncates rather than
    /// reaching under the notch.
    static func countText(total: Int, matches: Int?, locale: Locale = .current) -> String {
        let format = IntegerFormatStyle<Int>.number.locale(locale)
        guard let matches else { return total.formatted(format) }
        return "\(matches.formatted(format)) of \(total.formatted(format))"
    }
}
