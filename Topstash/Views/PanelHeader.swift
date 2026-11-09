import SwiftUI

/// The band beside the notch: the mode's title on the left; on the right, the note count and a
/// circular button (search in the list, close in search). Each side stops at the notch. One view for
/// the list and search, so switching swaps only its title, count, and symbol.
struct PanelHeader: View {
    let panel: PanelModel
    let actions: PanelActions
    /// Every note in the store.
    let total: Int
    /// The search results, or `nil` in the list and while the query is empty.
    let matches: Int?
    /// Search mode rather than the list. Passed in with the counts, not read from `panel`, so while
    /// the header fades out after closing, its title and count still belong to the same mode.
    let isSearch: Bool

    var body: some View {
        let sideWidth = PanelLayout.headerSideWidth(notchWidth: panel.notchWidth)
        HStack(spacing: 0) {
            Text(isSearch ? "Search" : "Recent")
                .font(PanelStyle.title)
                .foregroundStyle(PanelStyle.secondary)
                .contentTransition(.opacity)
                .frame(width: sideWidth, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            HStack(spacing: PanelLayout.headerSpacing) {
                count
                Button(action: isSearch ? actions.closeSearch : actions.openSearch) {
                    Image(systemName: isSearch ? "xmark" : "magnifyingglass")
                        .font(PanelStyle.headerIcon)
                        .foregroundStyle(PanelStyle.secondary)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: PanelLayout.headerButtonSize, height: PanelLayout.headerButtonSize)
                        .background(PanelStyle.surfaceFill, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSearch ? "Close" : "Search Notes")
            }
            .frame(width: sideWidth, alignment: .trailing)
        }
        .lineLimit(1)
        .padding(.horizontal, PanelLayout.inset)
        .frame(height: panel.headerHeight)
    }

    /// "4 of 12" when it fits beside the button, otherwise only the matches, "4".
    private var count: some View {
        ViewThatFits(in: .horizontal) {
            Text(Self.countText(total: total, matches: matches))
            if let matches {
                Text(Self.countText(total: matches, matches: nil))
            }
        }
        .font(PanelStyle.meta)
        .foregroundStyle(PanelStyle.tertiary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(matches.map { "\($0) of \(total) notes match" } ?? "\(total) notes")
    }

    /// "12" notes in the list; "4 of 12" matches in search.
    static func countText(total: Int, matches: Int?, locale: Locale = .current) -> String {
        let format = IntegerFormatStyle<Int>.number.locale(locale)
        guard let matches else { return total.formatted(format) }
        return "\(matches.formatted(format)) of \(total.formatted(format))"
    }
}
