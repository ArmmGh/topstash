import SwiftUI

/// The expanded panel: a search field above a scrollable list of the matching notes, newest first.
/// Results are recomputed on every keystroke. Esc closes the panel.
struct SearchView: View {
    let appModel: AppModel

    @FocusState private var isFieldFocused: Bool

    private var panel: PanelModel { appModel.panel }

    var body: some View {
        @Bindable var panel = appModel.panel
        VStack(spacing: PanelLayout.sectionSpacing) {
            TextField("Search notes", text: $panel.query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .focused($isFieldFocused)
                .padding(.horizontal, 12)
                .frame(height: PanelLayout.searchFieldHeight)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: PanelLayout.cardCornerRadius))
            results
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        // The shape is black in light and dark mode, so the field's placeholder and caret need dark colors.
        .environment(\.colorScheme, .dark)
        .onAppear { isFieldFocused = true }
        .onExitCommand { panel.mode = .closed }
    }

    @ViewBuilder
    private var results: some View {
        // Always read through `appModel.store`, which is replaced when the folder changes (#9).
        let notes = appModel.store.search(panel.query)
        if notes.isEmpty {
            Text("No matches")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity, minHeight: PanelLayout.rowHeight)
        } else {
            ScrollView {
                LazyVStack(spacing: PanelLayout.rowSpacing) {
                    ForEach(notes) { note in
                        NoteRow(
                            note: note,
                            isCopied: panel.copiedNoteID == note.id,
                            openInEditor: { appModel.openInEditor(note) },
                            delete: { appModel.delete(note) }
                        ) {
                            appModel.copy(note)
                        }
                    }
                }
            }
        }
    }
}
