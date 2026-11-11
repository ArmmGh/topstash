import Accessibility
import SwiftUI
import TopstashCore

/// The expanded panel under the header: a search field above a scrollable list of the matching notes, newest first.
/// Results are recomputed on every keystroke. The field keeps focus: ↑/↓ move the selection,
/// Return copies the selected note and closes the panel, ⌥Return can also paste it (a Settings
/// toggle), Space right after ↑/↓ peeks it, and Esc closes the peek, then the panel.
struct SearchView: View {
    let appModel: AppModel
    let actions: PanelActions
    /// `appModel.store.search(panel.query)`, searched once per update by `PanelView` for this list
    /// and the header's count.
    let results: [Note]

    @FocusState private var isFieldFocused: Bool
    /// Only for the key hints: `PanelActions.pasteFromSearch` reads the toggle itself.
    @AppStorage(Preferences.pastesOnOptionReturnKey) private var pastesOnOptionReturn = false
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
                    // Without this the field would type ⌥Return into the query, not submit.
                    .onKeyPress(.return, phases: .down) { press in
                        guard press.modifiers.contains(.option) else { return .ignored }
                        pasteSelected()
                        return .handled
                    }
                    // The field takes Return as submit before `onKeyPress` sees it.
                    .onSubmit(copySelected)
                    // Space and Esc reach `onKeyPress` before the field types or closes. While an
                    // input method composes, they're its keys.
                    .onKeyPress(.space, phases: [.down, .repeat]) { press in
                        // Only plain Space peeks: ⇧Space and the rest type, whatever runs first.
                        guard press.modifiers.isDisjoint(with: Self.shortcutModifiers), !fieldHasMarkedText
                        else { return .ignored }
                        // A held Space doesn't toggle again, nor type spaces after a toggle.
                        if press.phase == .repeat { return panel.spaceTogglesPeek ? .handled : .ignored }
                        return animatingPeek { panel.pressSpace(among: results) } ? .handled : .ignored
                    }
                    // `.handled` stops `onExitCommand`, so the panel stays open.
                    .onKeyPress(.escape, phases: .down) { _ in
                        guard !fieldHasMarkedText else { return .ignored }
                        return animatingPeek { panel.pressEscape() } ? .handled : .ignored
                    }
                    // Outermost, so it runs first: every key but plain Space makes Space type again.
                    // ↑/↓ then let it peek again.
                    .onKeyPress(phases: .down) { press in
                        if press.key != .space || !press.modifiers.isDisjoint(with: Self.shortcutModifiers) {
                            panel.pressOtherKey()
                        }
                        return .ignored
                    }
                // The shortcut's result. Not focusable, so typing continues in the field.
                if let status = panel.searchStatus {
                    SearchStatusBadge(status: status, bounceTrigger: reduceMotion ? 0 : panel.saveCount)
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
        .onAppear {
            isFieldFocused = true
            // When the search shortcut opens a closed panel, the focus set on appear is lost and
            // typing goes nowhere. Testing on macOS 27 showed the next turn of the run loop is too
            // early and 0.1 s is enough, so it's set again then.
            DispatchQueue.main.asyncAfter(deadline: .now() + Motion.searchFocusRetryDelay) {
                isFieldFocused = true
            }
        }
        .onExitCommand { actions.closeSearch() }
        // Typing selects the first result. Low priority, so it waits for VoiceOver's echo of the typing.
        // Closing clears the query too, which isn't typing.
        .onChange(of: panel.query) {
            if panel.mode == .search { announceSelection(priority: .low) }
        }
    }

    /// The keys the field takes, under the results: each key in `metaKey` and the secondary color,
    /// its label in `meta` and the tertiary color.
    private var keyHints: some View {
        HStack(spacing: PanelLayout.keyHintSpacing) {
            keyHint("⏎", "Copy")
            if pastesOnOptionReturn { keyHint("⌥⏎", "Paste") }
            keyHint("↑↓", "Move")
        }
        .frame(
            maxWidth: .infinity, minHeight: PanelLayout.keyHintsHeight, maxHeight: PanelLayout.keyHintsHeight,
            alignment: .leading
        )
        .padding(.horizontal, PanelLayout.inset)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Return copies the selected note.\(pastesOnOptionReturn ? " Option-Return pastes it." : "")"
                + " Up and down arrows move the selection.")
    }

    private func keyHint(_ key: String, _ label: LocalizedStringKey) -> some View {
        HStack(spacing: PanelLayout.keyHintLabelSpacing) {
            Text(verbatim: key)
                .font(PanelStyle.metaKey)
                .foregroundStyle(PanelStyle.secondary)
            Text(label)
                .font(PanelStyle.meta)
                .foregroundStyle(PanelStyle.tertiary)
        }
        .fixedSize()
    }

    /// ↑/↓: moves the selection, collapsing the peek, and announces the newly selected row.
    private func moveSelection(by step: Int) -> KeyPress.Result {
        if panel.peek == nil {
            panel.moveSelection(by: step, among: results.count)
        } else {
            animatingPeek { panel.moveSelection(by: step, among: results.count) }
        }
        announceSelection(priority: .high)
        return .handled
    }

    /// Runs `change` on `Motion.peek`, as a row peeks or collapses.
    private func animatingPeek<Result>(_ change: () -> Result) -> Result {
        withAnimation(Motion.peek(reduceMotion: reduceMotion), change)
    }

    /// The modifiers that make Space a different key: with any of them, Space types and never peeks.
    private static let shortcutModifiers: EventModifiers = [.shift, .control, .option, .command]

    /// Whether an input method is composing in the field: the field editor has marked text.
    private var fieldHasMarkedText: Bool {
        (NSApp.keyWindow?.firstResponder as? NSTextView)?.hasMarkedText() == true
    }

    /// Reads the selected row's title, since VoiceOver's focus stays in the field.
    private func announceSelection(
        priority: AttributeScopes.AccessibilityAttributes.AnnouncementPriorityAttribute.Value
    ) {
        guard let selectedNote else { return }
        var announcement = AttributedString(selectedNote.title)
        announcement.accessibilitySpeechAnnouncementPriority = priority
        AccessibilityNotification.Announcement(announcement).post()
    }

    /// Return: copies the selected note and closes the panel. With no results it does nothing.
    private func copySelected() {
        guard let selectedNote else { return }
        actions.copyFromSearch(selectedNote)
    }

    /// ⌥Return: like Return, and pastes too when the Settings toggle is on. With no results it
    /// does nothing.
    private func pasteSelected() {
        guard let selectedNote else { return }
        actions.pasteFromSearch(selectedNote)
    }
}
