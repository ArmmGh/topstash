import SwiftUI
import TopstashCore

/// Notes as `NoteRow`s wired to copy, Open in Editor, and Delete, or `emptyText` when there are none.
/// Shared by the recent list and the search results.
struct NoteList: View {
    let appModel: AppModel
    /// Closes the panel after Open in Editor.
    let actions: PanelActions
    let notes: [Note]
    let emptyText: LocalizedStringKey
    /// The search query, so each row's preview shows its match. `nil` in the recent list.
    var query: String?
    /// The search results scroll; the recent list always fits.
    var scrolls = false

    var body: some View {
        if notes.isEmpty {
            Text(emptyText)
                .font(PanelStyle.body)
                .foregroundStyle(PanelStyle.secondary)
                .frame(maxWidth: .infinity, minHeight: PanelLayout.rowHeight)
        } else if scrolls {
            ScrollView {
                LazyVStack(spacing: PanelLayout.rowSpacing) { rows }
            }
        } else {
            VStack(spacing: PanelLayout.rowSpacing) { rows }
        }
    }

    private var rows: some View {
        ForEach(notes) { note in
            NoteRow(
                note: note,
                query: query,
                isCopied: appModel.panel.copiedNote == note.id,
                openInEditor: {
                    appModel.openInEditor(note)
                    actions.dismissAfterAction()
                },
                delete: { appModel.delete(note) }
            ) {
                appModel.copy(note)
            }
        }
    }
}
