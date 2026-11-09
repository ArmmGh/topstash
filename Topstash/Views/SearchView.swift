import SwiftUI

/// The expanded panel: a search field above a scrollable list of the matching notes, newest first.
/// Results are recomputed on every keystroke. Esc closes the panel.
struct SearchView: View {
    let appModel: AppModel
    let actions: PanelActions

    @FocusState private var isFieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var panel: PanelModel { appModel.panel }

    var body: some View {
        @Bindable var panel = appModel.panel
        VStack(spacing: PanelLayout.sectionSpacing) {
            HStack(spacing: PanelLayout.searchStatusSpacing) {
                TextField("Search notes", text: $panel.query)
                    .textFieldStyle(.plain)
                    .font(PanelStyle.body)
                    .foregroundStyle(PanelStyle.primary)
                    .focused($isFieldFocused)
                // The shortcut's result. Not focusable, so typing continues in the field.
                if let status = panel.searchStatus {
                    SaveStatusBadge(result: status, bounceTrigger: reduceMotion ? 0 : panel.saveCount)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, PanelLayout.inset)
            .frame(height: PanelLayout.searchFieldHeight)
            .cardBackground()
            .animation(Motion.reduced, value: panel.searchStatus)
            results
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        // The shape is black in light and dark mode, so the field's placeholder and caret need dark colors.
        .environment(\.colorScheme, .dark)
        .onAppear { isFieldFocused = true }
        .onExitCommand { actions.closeSearch() }
    }

    private var results: some View {
        NoteList(
            appModel: appModel, actions: actions, notes: appModel.store.search(panel.query), emptyText: "No matches",
            scrolls: true)
    }
}
