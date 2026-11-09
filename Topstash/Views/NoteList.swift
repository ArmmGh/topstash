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

    /// Scrolls the results to keep the selection in view.
    @State private var scroller = RowScroller()

    var body: some View {
        if notes.isEmpty {
            Text(emptyText)
                .font(PanelStyle.body)
                .foregroundStyle(PanelStyle.secondary)
                .frame(maxWidth: .infinity, minHeight: PanelLayout.rowHeight)
        } else if scrolls {
            ScrollView {
                LazyVStack(spacing: PanelLayout.rowSpacing) { rows }
                    .background(EnclosingScrollView(scroller: scroller))
            }
            .onChange(of: selectedNote) { _, selected in
                guard let selected, let index = notes.firstIndex(where: { $0.id == selected }) else { return }
                scroller.show(row: index)
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
                copyCount: appModel.panel.copyCount,
                isSelected: selectedNote == note.id,
                openInEditor: {
                    appModel.openInEditor(note)
                    actions.dismissAfterAction()
                },
                delete: { appModel.delete(note) }
            ) {
                appModel.copy(note)
                actions.dismissAfterCopy()
            }
        }
    }
}

/// Keeps the keyboard selection in view by scrolling the results' `NSScrollView` directly, only as
/// far as needed. SwiftUI's `scrollTo` and `scrollPosition` remember the row they scrolled to and
/// bring it back after the user scrolls, so they aren't used.
@MainActor
private final class RowScroller {
    weak var scrollView: NSScrollView?

    func show(row index: Int) {
        guard let scrollView else { return }
        let clip = scrollView.contentView
        guard
            let offset = PanelLayout.scrollOffset(
                showingRow: index, offset: clip.bounds.minY, viewportHeight: clip.bounds.height)
        else { return }
        clip.scroll(to: NSPoint(x: clip.bounds.minX, y: offset))
        scrollView.reflectScrolledClipView(clip)
    }
}

/// Hands `RowScroller` the `NSScrollView` that SwiftUI's `ScrollView` is drawn in.
private struct EnclosingScrollView: NSViewRepresentable {
    let scroller: RowScroller

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        // Not in a window yet on the first update.
        DispatchQueue.main.async { scroller.scrollView = view.enclosingScrollView }
    }
}
