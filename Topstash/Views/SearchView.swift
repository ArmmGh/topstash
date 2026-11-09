import SwiftUI
import TopstashCore

/// The expanded panel under the header: a search field above a scrollable list of the matching notes, newest first.
/// Results are recomputed on every keystroke. The field keeps focus: ↑/↓ move the selection,
/// Return copies the selected note and closes the panel, and Esc closes it.
struct SearchView: View {
    let appModel: AppModel
    let actions: PanelActions
    /// `appModel.store.search(panel.query)`, searched once per update by `PanelView` for this list
    /// and the header's count.
    let results: [Note]

    @FocusState private var isFieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var panel: PanelModel { appModel.panel }

    /// The result ↑/↓ selected, which Return copies. `nil` with no results.
    private var selectedNote: Note? {
        panel.selectedResult(among: results.count).map { results[$0] }
    }

    var body: some View {
        @Bindable var panel = appModel.panel
        VStack(spacing: PanelLayout.sectionSpacing) {
            HStack(spacing: PanelLayout.searchFieldSpacing) {
                Image(systemName: "magnifyingglass")
                    .font(PanelStyle.searchIcon)
                    .foregroundStyle(PanelStyle.secondary)
                    .accessibilityHidden(true)
                TextField("Search notes", text: $panel.query)
                    .textFieldStyle(.plain)
                    .font(PanelStyle.body)
                    .foregroundStyle(PanelStyle.primary)
                    .focused($isFieldFocused)
                    .onKeyPress(.upArrow) { moveSelection(by: -1) }
                    .onKeyPress(.downArrow) { moveSelection(by: 1) }
                    // The field takes Return as submit before `onKeyPress` sees it.
                    .onSubmit(copySelected)
                // The shortcut's result. Not focusable, so typing continues in the field.
                if let status = panel.searchStatus {
                    SaveStatusBadge(result: status, bounceTrigger: reduceMotion ? 0 : panel.saveCount)
                        .transition(.opacity)
                }
                // Esc closes the panel.
                Text("esc")
                    .font(PanelStyle.meta)
                    .foregroundStyle(PanelStyle.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, PanelLayout.inset)
            .frame(height: PanelLayout.searchFieldHeight)
            .cardBackground(cornerRadius: PanelLayout.searchFieldCornerRadius)
            .animation(Motion.reduced, value: panel.searchStatus)
            NoteList(
                appModel: appModel, actions: actions, notes: results, emptyText: "No matches", query: panel.query,
                selectedNote: selectedNote?.id, scrolls: true
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // The keys do nothing without results.
            if !results.isEmpty { keyHints }
        }
        .padding(.horizontal, PanelLayout.inset)
        // The shape is black in light and dark mode, so the field's placeholder and caret need dark colors.
        .environment(\.colorScheme, .dark)
        .onAppear { isFieldFocused = true }
        .onExitCommand { actions.closeSearch() }
    }

    /// The keys the field takes, under the results.
    private var keyHints: some View {
        HStack(spacing: PanelLayout.keyHintSpacing) {
            Text("⏎ Copy")
            Text("↑↓ Move")
        }
        .font(PanelStyle.meta)
        .foregroundStyle(PanelStyle.tertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PanelLayout.inset)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Return copies the selected note. Up and down arrows move the selection.")
    }

    /// ↑/↓: moves the selection and announces the newly selected row, since VoiceOver's focus
    /// stays in the field.
    private func moveSelection(by step: Int) -> KeyPress.Result {
        panel.moveSelection(by: step, among: results.count)
        if let selectedNote {
            AccessibilityNotification.Announcement(selectedNote.title).post()
        }
        return .handled
    }

    /// Return: copies the selected note and closes the panel at once, handing focus back to the app
    /// the user was in. With no results it does nothing.
    private func copySelected() {
        guard let selectedNote else { return }
        appModel.copy(selectedNote)
        actions.closeSearch()
    }
}
