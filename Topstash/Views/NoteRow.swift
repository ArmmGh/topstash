import SwiftUI
import TopstashCore

/// One note in the recent list or the search results: its title and preview, and its age on the right.
/// Clicking it copies the note. Right-clicking offers "Open in Editor" and "Delete".
/// In search, the keyboard-selected row has a ring on the hover fill.
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
    let openInEditor: () -> Void
    let delete: () -> Void
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let preview = previewText
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: PanelLayout.rowAgeSpacing) {
                VStack(alignment: .leading, spacing: PanelLayout.rowLineSpacing) {
                    Text(note.title)
                        .font(PanelStyle.title)
                        .foregroundStyle(PanelStyle.primary)
                    // A one-line note has no preview, so its title centers in the row.
                    Group {
                        if isCopied {
                            CopiedLabel(bounceTrigger: reduceMotion ? 0 : copyCount)
                        } else if !preview.characters.isEmpty {
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
            }
            .padding(.horizontal, PanelLayout.inset)
            // Every row is exactly this tall: `PanelLayout.scrollOffset` works out where rows are from it.
            .frame(height: PanelLayout.rowHeight)
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
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .contextMenu {
            Button("Open in Editor", action: openInEditor)
            Divider()
            Button("Delete", role: .destructive, action: delete)
        }
        .onHover { isHovered = $0 }
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

/// "Copied" with the save's checkmark, in the primary color, which bounces as it comes in and on
/// every copy after. Not with Reduce Motion (`bounceTrigger` 0).
private struct CopiedLabel: View {
    let bounceTrigger: Int

    /// Bumped when the label appears and on every copy while it shows: it's inserted in the same
    /// update that bumps `copyCount`, so a `symbolEffect` keyed on the count alone wouldn't play
    /// the first time (as in `SaveStatusBadge`).
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
