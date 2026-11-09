import SwiftUI
import TopstashCore

/// The expanded panel under the header: a search field above a scrollable list of the matching notes, newest first.
/// Results are recomputed on every keystroke. Esc closes the panel.
struct SearchView: View {
    let appModel: AppModel
    let actions: PanelActions
    /// `appModel.store.search(panel.query)`, searched once per update by `PanelView` for this list
    /// and the header's count.
    let results: [Note]

    @FocusState private var isFieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var panel: PanelModel { appModel.panel }

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
                appModel: appModel, actions: actions, notes: results, emptyText: "No matches", scrolls: true
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, PanelLayout.inset)
        // The shape is black in light and dark mode, so the field's placeholder and caret need dark colors.
        .environment(\.colorScheme, .dark)
        .onAppear { isFieldFocused = true }
        .onExitCommand { actions.closeSearch() }
    }
}
