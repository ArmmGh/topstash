import AppKit
import Observation
import os
import TopstashCore

/// The composition root, and the actions shared by the save card, the menu bar, and the shortcut.
@MainActor @Observable
final class AppModel {
    /// The notes folder's store. Replaced, together with its watcher, only by `setFolder(_:)`, so
    /// views read `appModel.store` each time rather than keep a reference to a store.
    private(set) var store: NotesStore
    let panel: PanelModel
    let clipboard: any Clipboard

    @ObservationIgnored
    private var copiedResetTask: Task<Void, Never>?
    @ObservationIgnored
    private let logger = Logger(category: "AppModel")

    /// Opens the notes folder, creating it if it's missing. Tests pass their own defaults and a fake clipboard.
    init(defaults: UserDefaults = .standard, clipboard: any Clipboard = SystemClipboard()) {
        let folder = Preferences.notesFolder(defaults)
        self.defaults = defaults
        panel = PanelModel()
        self.clipboard = clipboard
        // There's no other folder to fall back to at startup, so a folder that can't be created is
        // only logged, and its store has no notes.
        (store, watcher) = Self.open(folder) { error in
            Logger(category: "AppModel")
                .error("Couldn't create the notes folder \(folder.path(percentEncoded: false), privacy: .public): \(error)")
        }
    }

    /// Reads the clipboard and saves its text as a note. Logs a write error before returning `.failed`.
    func saveClipboard() -> ClipboardSaveResult {
        let changeCount = clipboard.changeCount
        let read = clipboard.readText()
        if let read, clipboard.changeCount == changeCount {
            knownClipboard = (read, changeCount)
        }
        // Reading returned nothing although the clipboard holds text: paste access is denied,
        // in Settings or at the alert this read showed.
        if read == nil, clipboard.hasText() {
            return .accessDenied
        }
        do {
            switch try store.save(read ?? "") {
            case .saved(let note): return .saved(note)
            case .alreadySaved: return .alreadySaved
            case .empty: return .nothingToSave
            }
        } catch {
            logger.error("Saving the clipboard failed: \(error)")
            return .failed
        }
    }

    /// Copies the note's full body to the clipboard and shows "Copied" on its row for a moment.
    /// Nothing about the note or the order of notes changes.
    func copy(_ note: Note) {
        clipboard.write(note.body)
        knownClipboard = (note.body, clipboard.changeCount)
        panel.copiedNote = note.id
        copiedResetTask?.cancel()
        copiedResetTask = .afterDelay(Motion.copiedDuration) { [weak self] in
            self?.panel.copiedNote = nil
        }
        // The clipboard now holds a saved note, so the card reads "Already saved".
        refreshSaveCard()
    }

    // MARK: - Save card (#3)

    @ObservationIgnored
    private var saveCardResetTask: Task<Void, Never>?

    /// The text the app itself last put on (copy) or read from (save) the clipboard, with the
    /// clipboard's `changeCount` at that moment. While the count is unchanged, the clipboard still
    /// holds this text, so the card can say "Already saved" without reading the clipboard (#3, #4).
    @ObservationIgnored
    private var knownClipboard: (text: String, changeCount: Int)?

    /// `knownClipboard`'s text, if nothing has replaced it since.
    private var knownClipboardText: String? {
        guard let knownClipboard, knownClipboard.changeCount == clipboard.changeCount else { return nil }
        return knownClipboard.text
    }

    /// Sets the save card from the clipboard. Called when the panel opens, after `copy`,
    /// and when a transient "Saved" or "Couldn't save" ends.
    /// Reads the clipboard's contents only when that can't show the paste privacy alert (#4).
    func refreshSaveCard() {
        guard clipboard.hasText() else {
            panel.saveCard = .nothingToSave
            return
        }
        // Text the app copied or saved itself is known even when reading would show the alert.
        if let text = knownClipboardText, store.contains(text) {
            panel.saveCard = .alreadySaved
            return
        }
        switch clipboard.access {
        case .allowed:
            break
        case .wouldPrompt:
            panel.saveCard = .readyWithoutPreview
            return
        case .denied:
            panel.saveCard = .accessDenied
            return
        }
        let text = clipboard.readText() ?? ""
        // Stops at the first visible character, unlike trimming a copy of the whole text.
        if text.allSatisfy(\.isWhitespace) {
            panel.saveCard = .nothingToSave
        } else if store.contains(text) {
            panel.saveCard = .alreadySaved
        } else {
            panel.saveCard = Self.previewCard(for: text)
        }
    }

    /// Shows a save's result on the card: the card's click, and the shortcut (#10).
    /// "Saved", "Nothing to save", and "Couldn't save" are transient: they revert to the clipboard's
    /// state after their `cardRevertDelay`, unless `reverts` is false (the shortcut's feedback panel, which hides
    /// or refreshes the card itself when its time is up).
    func showSaveResult(_ result: ClipboardSaveResult, reverts: Bool = true) {
        saveCardResetTask?.cancel()
        panel.saveCard = result.cardState
        if case .saved = result {
            playSaveFeedback()
        }
        guard reverts, let revertDelay = result.cardRevertDelay else { return }
        saveCardResetTask = .afterDelay(revertDelay) { [weak self] in
            self?.refreshSaveCard()
        }
    }

    /// Shows the shortcut's result while searching (#10). The search view has no card, so it shows
    /// the result next to the search field for `Motion.feedbackDuration`. The search stays open and focused.
    func showSaveResultInSearch(_ result: ClipboardSaveResult) {
        panel.searchStatus = result
        if case .saved = result {
            playSaveFeedback()
        }
        searchStatusResetTask?.cancel()
        searchStatusResetTask = .afterDelay(Motion.feedbackDuration) { [weak self] in
            self?.panel.searchStatus = nil
        }
    }

    @ObservationIgnored
    private var searchStatusResetTask: Task<Void, Never>?

    /// The card for a save the shortcut made while the panel was closed (#10), until its feedback
    /// plays: the saved text as if it were unsaved, so it has a card to fly up (#11).
    func showCardBeforeSave(of text: String) {
        saveCardResetTask?.cancel()
        panel.saveCard = Self.previewCard(for: text)
    }

    /// Keeps only the part of the text the card shows, so the panel doesn't hold, and compare on
    /// every update, a clipboard that may be megabytes long.
    private static func previewCard(for text: String) -> SaveCardState {
        .preview(text: SaveCard.previewText(text), characterCount: text.count)
    }

    /// The haptic, and through `panel.saveCount` the checkmark bounce and the notch's gulp (#11).
    /// Here rather than in a view, so it plays however the save happened and whatever is on screen.
    private func playSaveFeedback() {
        panel.saveCount += 1
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }

    // MARK: - Notes folder (#9)

    @ObservationIgnored
    private let defaults: UserDefaults

    /// Reloads the store, off the main thread, whenever the folder changes on disk. Our own saves
    /// trigger a reload too, which is harmless: `notes` is assigned only when something changed.
    @ObservationIgnored
    private var watcher: FolderWatcher

    /// The one path that opens a notes folder, at startup and when switching: creates the folder if
    /// it's missing, then a store and a watcher for it, so the two always belong to the same folder.
    /// If the folder can't be created, `onCreateFailure` decides: it throws to open nothing, or
    /// returns to open the folder anyway.
    private static func open(
        _ folder: URL,
        onCreateFailure: (any Error) throws -> Void
    ) rethrows -> (NotesStore, FolderWatcher) {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            try onCreateFailure(error)
        }
        let store = NotesStore(folder: folder)
        let watcher = FolderWatcher(folder: folder) { [weak store] in
            store?.reloadInBackground()
        }
        watcher.start()
        return (store, watcher)
    }

    /// Switches to another notes folder: opens it, which loads its notes right away, stores its path,
    /// and stops watching the old folder. If the folder can't be created, this throws and the old
    /// folder stays active.
    func setFolder(_ url: URL) throws {
        let (newStore, newWatcher) = try Self.open(url) { throw $0 }
        watcher.stop()
        store = newStore
        watcher = newWatcher
        defaults.set(url.path(percentEncoded: false), forKey: Preferences.notesFolderPathKey)
        // "Copied" belongs to a note of the old folder, and the clipboard may count as saved now.
        panel.copiedNote = nil
        refreshSaveCard()
    }

    /// The size of the shape's body in the current mode. `PanelView` draws it, and
    /// `NotchPanelController` hit-tests against it.
    var shapeSize: CGSize {
        PanelLayout.shapeSize(for: panel.mode, closedSize: panel.closedSize, noteCount: store.notes.count)
    }

    // MARK: - Context menu (#6)

    /// Opens the note's file in the default app for `.md`. If no app handles `.md`, macOS shows
    /// its own app chooser. The note row then closes the panel through `PanelActions`.
    func openInEditor(_ note: Note) {
        NSWorkspace.shared.open(note.fileURL)
    }

    /// Moves the note's file to the Trash. On failure, logs and beeps.
    func delete(_ note: Note) {
        do {
            try store.delete(note)
        } catch {
            logger.error("Deleting \(note.fileURL.path(percentEncoded: false), privacy: .public) failed: \(error)")
            NSSound.beep()
        }
        // The clipboard text may no longer count as saved.
        refreshSaveCard()
    }
}
