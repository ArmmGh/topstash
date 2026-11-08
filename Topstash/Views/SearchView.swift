import SwiftUI

/// The expanded panel: a search field above a scrollable list of the matching notes, newest first.
/// Results are recomputed on every keystroke. Esc closes the panel.
struct SearchView: View {
    let appModel: AppModel

    @FocusState private var isFieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var panel: PanelModel { appModel.panel }

    var body: some View {
        @Bindable var panel = appModel.panel
        VStack(spacing: PanelLayout.sectionSpacing) {
            HStack(spacing: 8) {
                TextField("Search notes", text: $panel.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .focused($isFieldFocused)
                // The shortcut's result (#10). Not focusable, so typing continues in the field.
                if let status = panel.searchStatus {
                    SaveStatusBadge(state: status, bounceTrigger: reduceMotion ? 0 : panel.saveCount)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: PanelLayout.searchFieldHeight)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: PanelLayout.cardCornerRadius))
            .animation(Motion.searchStatus, value: panel.searchStatus)
            results
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        // The shape is black in light and dark mode, so the field's placeholder and caret need dark colors.
        .environment(\.colorScheme, .dark)
        .onAppear { isFieldFocused = true }
        .onExitCommand { panel.mode = .closed }
    }

    private var results: some View {
        // Always read through `appModel.store`, which is replaced when the folder changes (#9).
        NoteList(appModel: appModel, notes: appModel.store.search(panel.query), emptyText: "No matches", scrolls: true)
    }
}
