import SwiftUI
import TopstashCore

/// One note in the recent list or the search results: its title and preview, and its age on the right.
/// Clicking it copies the note. Right-clicking offers "Preview", "Open in Editor" and "Delete".
/// While hovered, a chevron replaces the age and toggles the peek; it's the one part that doesn't copy.
/// In search, the keyboard-selected row has a ring on the hover fill.
/// While it peeks, the row is taller and shows the note's text under the title in place of the preview.
struct NoteRow: View {
    let note: Note
    /// The search query, so the preview shows the part of the note that matched. `nil` in the recent list.
    let query: String?
    /// Shows "Copied" in place of the preview.
    let isCopied: Bool
    /// `PanelModel.copyCount`: bounces the checkmark on every copy.
    let copyCount: Int
    /// The search result ↑/↓ selected, which Return copies.
    let isSelected: Bool
    /// Set while this row peeks: the text it shows and how much taller it is.
    let peek: NotePeek?
    /// Expands or collapses this row's peek. Never copies.
    let togglePeek: () -> Void
    let openInEditor: () -> Void
    let delete: () -> Void
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let preview = previewText
        // A one-line note's peek has no text: its row looks as it does collapsed.
        let peekText = peek.map(\.text).flatMap { $0.isEmpty ? nil : $0 }
        Button(action: action) {
            VStack(alignment: .leading, spacing: PanelLayout.rowLineSpacing) {
                titleLine(preview: preview, peeks: peekText != nil)
                if let peek, let peekText, !isCopied {
                    PeekBody(text: peekText, height: peek.bodyHeight)
                        .transition(Motion.copiedLine(reduceMotion: reduceMotion))
                }
            }
            .padding(.horizontal, PanelLayout.inset)
            // A peek's title stays where it was collapsed, so "Copied" in a tall row doesn't move it.
            .padding(.top, peekText == nil ? 0 : PanelLayout.rowVerticalPadding)
            // Every row is exactly this tall: `PanelLayout.scrollOffset` works out where rows are from it.
            .frame(
                height: PanelLayout.rowHeight + (peek?.extraHeight ?? 0),
                alignment: peekText == nil ? .center : .top
            )
            .background {
                // Hovering another row shows its fill without moving the selection. The copied row
                // keeps its fill while it shows "Copied", wherever the cursor goes.
                if isSelected || isHovered || isCopied { rowShape.fill(PanelStyle.hoverFill) }
                if isSelected {
                    rowShape.strokeBorder(PanelStyle.selectionRing, lineWidth: PanelLayout.selectionRingWidth)
                }
            }
            .contentShape(rowShape)
        }
        // Dips while pressed, like the save card.
        .buttonStyle(PressDipButtonStyle())
        // Over the age, but outside the row's label, so clicking it doesn't copy.
        .overlayPreferenceValue(AgeBounds.self) { age in
            if let age, Self.trailingSlot(isHovered: isHovered, peeks: peek != nil) == .chevron {
                GeometryReader { proxy in
                    let bounds = proxy[age]
                    PeekChevron(isExpanded: peek != nil, toggle: togglePeek)
                        .position(x: bounds.maxX - PanelLayout.peekChevronSize / 2, y: bounds.midY)
                }
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAction(named: "Preview", togglePeek)
        .contextMenu {
            Button("Preview", action: togglePeek)
            Button("Open in Editor", action: openInEditor)
            Divider()
            Button("Delete", role: .destructive, action: delete)
        }
        .onHover { isHovered = $0 }
    }

    /// The title, the preview line under it (or "Copied"), and the age on the right. While the row
    /// peeks, the peek takes the preview's place.
    private func titleLine(preview: AttributedString, peeks: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: PanelLayout.rowAgeSpacing) {
            VStack(alignment: .leading, spacing: PanelLayout.rowLineSpacing) {
                Text(note.title)
                    .font(PanelStyle.title)
                    .foregroundStyle(PanelStyle.primary)
                // A one-line note has no preview, so its title centers in the row.
                Group {
                    if isCopied {
                        CopiedLabel(bounceTrigger: reduceMotion ? 0 : copyCount)
                    } else if !peeks, !preview.characters.isEmpty {
                        Text(preview)
                            .foregroundStyle(PanelStyle.secondary)
                    }
                }
                .font(PanelStyle.meta)
                .transition(Motion.copiedLine(reduceMotion: reduceMotion))
            }
            .animation(reduceMotion ? Motion.reduced : Motion.copiedSwap, value: isCopied)
            .lineLimit(1)
            .truncationMode(.tail)
            Spacer(minLength: 0)
            Text(NoteAge.text(created: note.created, now: .now))
                .font(PanelStyle.meta)
                .foregroundStyle(PanelStyle.tertiary)
                .fixedSize()
                .accessibilityLabel(Text(note.created, format: .relative(presentation: .named)))
                // Keeps its place while the chevron covers it, so the title doesn't move.
                .opacity(Self.trailingSlot(isHovered: isHovered, peeks: peek != nil) == .age ? 1 : 0)
                .anchorPreference(key: AgeBounds.self, value: .bounds) { $0 }
        }
    }

    /// What a row shows right of its title.
    enum TrailingSlot: Equatable {
        /// How long ago the note was saved.
        case age
        /// The control that expands and collapses the peek.
        case chevron
    }

    /// The chevron replaces the age while the row is hovered, and stays while the row peeks so it
    /// can be collapsed.
    static func trailingSlot(isHovered: Bool, peeks: Bool) -> TrailingSlot {
        isHovered || peeks ? .chevron : .age
    }

    /// The note's preview, or in search, the snippet around its match.
    private var previewText: AttributedString {
        guard let query else { return AttributedString(note.preview) }
        let snippet = SearchSnippet(body: note.body, query: query)
        return Self.snippetText(snippet, matchColor: PanelStyle.primary.color(contrast: contrast))
    }

    /// The snippet with its matches in `PanelStyle.metaMatch` and `matchColor`, so they stand out by
    /// weight as well as color. The rest takes the row's preview style.
    static func snippetText(_ snippet: SearchSnippet, matchColor: Color) -> AttributedString {
        let text = snippet.text
        var attributed = AttributedString()
        var rest = text.startIndex
        for range in snippet.matches {
            attributed += AttributedString(text[rest..<range.lowerBound])
            var match = AttributedString(text[range])
            match.swiftUI.font = PanelStyle.metaMatch
            match.swiftUI.foregroundColor = matchColor
            attributed += match
            rest = range.upperBound
        }
        attributed += AttributedString(text[rest...])
        return attributed
    }

    private var rowShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PanelLayout.rowCornerRadius)
    }
}

/// Where the row's age is, so the chevron can be drawn over it from outside the row's label.
private struct AgeBounds: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

/// Points right on a collapsed row and down on an expanded one, turning on the row's height spring
/// (`NoteList.togglePeek`). Doesn't turn with Reduce Motion. VoiceOver uses the row's "Preview"
/// action instead.
private struct PeekChevron: View {
    let isExpanded: Bool
    let toggle: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: toggle) {
            Image(systemName: "chevron.right")
                .font(PanelStyle.peekChevron)
                .foregroundStyle(PanelStyle.secondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .transaction(value: isExpanded) { if reduceMotion { $0.animation = nil } }
                .frame(width: PanelLayout.peekChevronSize, height: PanelLayout.peekChevronSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHidden(true)
    }
}

/// A peeking row's text under its title: raw, wrapped, with its line breaks, in `meta` and the
/// secondary color. `height` fits up to `PanelLayout.maxPeekLines` lines; longer text scrolls here.
/// Not selectable, since a click on it copies the note like a click anywhere on the row.
private struct PeekBody: View {
    let text: String
    let height: CGFloat

    var body: some View {
        ScrollView {
            Text(verbatim: text)
                .font(PanelStyle.meta)
                .foregroundStyle(PanelStyle.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        // Only text that overflows scrolls, so a short peek leaves scrolling to the results list.
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: height)
    }
}

/// "Copied" with the save's checkmark, in the primary color, which bounces as it comes in and on
/// every copy after. Not with Reduce Motion (`bounceTrigger` 0).
private struct CopiedLabel: View {
    let bounceTrigger: Int

    /// Bumped when the label appears and on every copy while it shows: it's inserted in the same
    /// update that bumps `copyCount`, so a `symbolEffect` keyed on the count alone wouldn't play
    /// the first time (as in `SearchStatusBadge`).
    @State private var bounces = 0

    var body: some View {
        HStack(spacing: PanelLayout.inlineSpacing) {
            Image(systemName: "checkmark.circle.fill")
                .symbolEffect(.bounce, value: bounces)
                .task { if bounceTrigger != 0 { bounces += 1 } }
                .onChange(of: bounceTrigger) { bounces += 1 }
            Text("Copied")
        }
        .foregroundStyle(PanelStyle.primary)
        .accessibilityElement(children: .combine)
    }
}
