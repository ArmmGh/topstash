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
    /// The search result ↑/↓ selected, kept in view as it moves. `nil` in the recent list.
    var selectedNote: Note.ID?
    /// The search results scroll; the recent list always fits.
    var scrolls = false

    /// The results' scroll offset and visible height, for keeping the selection in view. Not
    /// observed, so scrolling doesn't redraw the list.
    @State private var scrollMetrics = ScrollMetrics()

    var body: some View {
        if notes.isEmpty {
            Text(emptyText)
                .font(PanelStyle.body)
                .foregroundStyle(PanelStyle.secondary)
                .frame(maxWidth: .infinity, minHeight: PanelLayout.rowHeight)
        } else if scrolls {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: PanelLayout.rowSpacing) { rows }
                        .onGeometryChange(for: CGFloat.self) {
                            -$0.frame(in: .scrollView).minY
                        } action: {
                            scrollMetrics.offset = $0
                        }
                }
                .onGeometryChange(for: CGFloat.self) {
                    $0.size.height
                } action: {
                    scrollMetrics.viewportHeight = $0
                }
                // Only as far as needed: `scrollTo` without an anchor scrolls even to a row in view.
                .onChange(of: selectedNote) { _, selected in
                    guard let selected, let index = notes.firstIndex(where: { $0.id == selected }) else { return }
                    let anchor = PanelLayout.scrollAnchor(
                        row: index, offset: scrollMetrics.offset, viewportHeight: scrollMetrics.viewportHeight)
                    if let anchor { proxy.scrollTo(selected, anchor: anchor) }
                }
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
                isSelected: selectedNote == note.id,
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

/// Where the search results are scrolled, written as they scroll and read when the selection moves.
private final class ScrollMetrics {
    /// How far the results are scrolled down from the top.
    var offset: CGFloat = 0
    /// The height of the visible part of the results.
    var viewportHeight: CGFloat = 0
}
