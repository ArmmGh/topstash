import SwiftUI
import TopstashCore

/// One note in the recent list: its title and preview, and its age on the right. Clicking it copies
/// the note. Right-clicking offers "Open in Editor" and "Delete".
struct NoteRow: View {
    let note: Note
    /// Shows "Copied" in place of the preview.
    let isCopied: Bool
    let openInEditor: () -> Void
    let delete: () -> Void
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: PanelLayout.rowAgeSpacing) {
                VStack(alignment: .leading, spacing: PanelLayout.rowLineSpacing) {
                    Text(note.title)
                        .font(PanelStyle.title)
                        .foregroundStyle(PanelStyle.primary)
                    // A one-line note has no preview, so its title centers in the row.
                    Group {
                        if isCopied {
                            Label("Copied", systemImage: "checkmark")
                        } else if !note.preview.isEmpty {
                            Text(note.preview)
                        }
                    }
                    .font(PanelStyle.meta)
                    .foregroundStyle(PanelStyle.secondary)
                }
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
            .frame(height: PanelLayout.rowHeight)
            .background(isHovered ? PanelStyle.hoverFill : PanelColor.clear, in: rowShape)
            .contentShape(rowShape)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open in Editor", action: openInEditor)
            Divider()
            Button("Delete", role: .destructive, action: delete)
        }
        .onHover { isHovered = $0 }
    }

    private var rowShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PanelLayout.rowCornerRadius)
    }
}
