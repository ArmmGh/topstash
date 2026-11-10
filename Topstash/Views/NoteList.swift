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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var panel: PanelModel { appModel.panel }

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
                guard let selected else { return }
                show(selected)
            }
            .onChange(of: panel.peekedNote) { _, peeked in
                guard let peeked else { return }
                // The results' scroll view grows only once the taller row is laid out: try on the
                // next turn of the run loop, and again once the row has finished growing.
                DispatchQueue.main.async { show(peeked) }
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + Motion.expandSettleDuration(reduceMotion: reduceMotion)
                ) {
                    if panel.peekedNote == peeked { show(peeked) }
                }
            }
        } else {
            VStack(spacing: PanelLayout.rowSpacing) { rows }
        }
    }

    /// Scrolls the results just far enough to show the note's row, taller while it peeks.
    private func show(_ note: Note.ID) {
        guard let index = notes.firstIndex(where: { $0.id == note }) else { return }
        let peek = panel.peek
        scroller.show(
            row: index, peekedRow: peek.flatMap { peek in notes.firstIndex { $0.id == peek.note } },
            peekExtraHeight: peek?.extraHeight ?? 0)
    }

    /// One peek at a time, the rows below moving with the shape's edge on its opening spring both
    /// ways (the closing one waits for content to fade out). Only fades with Reduce Motion.
    private func togglePeek(_ note: Note) {
        withAnimation(Motion.shape(expanding: true, reduceMotion: reduceMotion)) {
            panel.togglePeek(note)
        }
    }

    private var rows: some View {
        ForEach(notes) { note in
            NoteRow(
                note: note,
                query: query,
                isCopied: panel.copiedNote == note.id,
                copyCount: panel.copyCount,
                isSelected: selectedNote == note.id,
                peek: panel.peek?.note == note.id ? panel.peek : nil,
                togglePeek: { togglePeek(note) },
                openInEditor: {
                    appModel.openInEditor(note)
                    actions.dismissAfterAction()
                },
                delete: { appModel.delete(note) }
            ) {
                // The mouse-up that ends a force click.
                guard !panel.consumeCopySuppression(note.id) else { return }
                appModel.copy(note)
                actions.dismissAfterCopy()
            }
            // So a force click knows which row it's on.
            .onHover { panel.hover(note, $0) }
        }
    }
}

/// Keeps the keyboard selection in view by scrolling the results' `NSScrollView` directly, only as
/// far as needed. SwiftUI's `scrollTo` and `scrollPosition` remember the row they scrolled to and
/// bring it back after the user scrolls, so they aren't used.
@MainActor
private final class RowScroller {
    weak var scrollView: NSScrollView?

    func show(row index: Int, peekedRow: Int?, peekExtraHeight: CGFloat) {
        guard let scrollView else { return }
        let clip = scrollView.contentView
        guard
            let offset = PanelLayout.scrollOffset(
                showingRow: index, peekedRow: peekedRow, peekExtraHeight: peekExtraHeight,
                offset: clip.bounds.minY, viewportHeight: clip.bounds.height)
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
