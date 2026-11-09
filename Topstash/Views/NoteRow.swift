import SwiftUI
import TopstashCore

/// One note in the recent list: its title and preview. Clicking it copies the note.
/// Right-clicking offers "Open in Editor" and "Delete".
struct NoteRow: View {
    let note: Note
    /// Shows "Copied" in place of the preview.
    let isCopied: Bool
    let openInEditor: () -> Void
    let delete: () -> Void
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: PanelLayout.rowLineSpacing) {
                Text(note.title)
                    .font(PanelStyle.rowTitle)
                    .foregroundStyle(PanelStyle.primary)
                Group {
                    if isCopied {
                        Label("Copied", systemImage: "checkmark")
                    } else {
                        Text(note.preview)
                    }
                }
                .font(PanelStyle.caption)
                .foregroundStyle(PanelStyle.secondary)
            }
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, PanelLayout.rowHorizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: PanelLayout.rowHeight)
            .contentShape(RoundedRectangle(cornerRadius: PanelLayout.rowCornerRadius))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open in Editor", action: openInEditor)
            Divider()
            Button("Delete", role: .destructive, action: delete)
        }
    }
}
