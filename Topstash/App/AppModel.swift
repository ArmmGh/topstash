import AppKit
import Observation
import os
import TopstashCore

/// The composition root, and the actions shared by the save card, the menu bar, and the shortcut.
@MainActor @Observable
final class AppModel {
    /// Replaced when the folder changes (#9). Views always read `appModel.store`.
    private(set) var store: NotesStore
    let panel: PanelModel
    let clipboard: Clipboard

    @ObservationIgnored
    private var copiedResetTask: Task<Void, Never>?
    @ObservationIgnored
    private let logger = Logger(category: "AppModel")

    /// Creates the notes folder if it's missing.
    init(defaults: UserDefaults = .standard) {
        let folder = Preferences.notesFolder(defaults)
        self.defaults = defaults
        store = NotesStore(folder: folder)
        panel = PanelModel()
        clipboard = Clipboard()
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            logger.error("Couldn't create the notes folder \(folder.path(percentEncoded: false), privacy: .public): \(error)")
        }
        startWatching(folder)
    }

    /// Reloads the store, off the main thread, whenever the folder changes on disk. Our own saves
    /// trigger a reload too, which is harmless: `notes` is assigned only when something changed.
    @ObservationIgnored
    private var watcher: FolderWatcher?

    /// Replaces the current watcher (#9 calls this when the folder changes).
    private func startWatching(_ folder: URL) {
        watcher?.stop()
        let watcher = FolderWatcher(folder: folder) { [weak self] in
            self?.store.reloadInBackground()
        }
        watcher.start()
        self.watcher = watcher
    }

    /// Reading the clipboard returned nothing although it holds text: paste access is denied,
    /// in Settings or at the alert this read showed.
    struct ClipboardAccessDenied: Error {}

    /// Reads the clipboard and saves its text as a note. Fails with `ClipboardAccessDenied` when
    /// the clipboard holds text that Topstash isn't allowed to read.
    func saveClipboard() -> Result<SaveResult, any Error> {
        let changeCount = clipboard.changeCount
        let read = clipboard.readText()
        if let read, clipboard.changeCount == changeCount {
            knownClipboard = (read, changeCount)
        }
        if read == nil, clipboard.hasText() {
            return .failure(ClipboardAccessDenied())
        }
        let text = read ?? ""
        do {
            return .success(try store.save(text))
        } catch {
            logger.error("Saving the clipboard failed: \(error)")
            return .failure(error)
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
    /// state after a moment, unless `reverts` is false (the shortcut's feedback panel, which hides
    /// or refreshes the card itself when its time is up).
    func showSaveResult(_ result: Result<SaveResult, any Error>, reverts: Bool = true) {
        saveCardResetTask?.cancel()
        let state = Self.cardState(for: result)
        panel.saveCard = state
        if state == .saved {
            playSaveFeedback()
        }
        let revertDelay: Double? = switch state {
        // The checkmark shows for the save feedback's length (#11), then the card returns.
        case .saved: Motion.saveFeedbackDuration
        case .nothingToSave: Motion.nothingToSaveDuration
        case .failed: Motion.failedDuration
        // "Already saved" is the clipboard's state anyway.
        default: nil
        }
        guard reverts, let revertDelay else { return }
        saveCardResetTask = .afterDelay(revertDelay) { [weak self] in
            self?.refreshSaveCard()
        }
    }

    /// Shows the shortcut's result while searching (#10). The search view has no card, so it shows
    /// the result next to the search field for `Motion.feedbackDuration`. The search stays open and focused.
    func showSaveResultInSearch(_ result: Result<SaveResult, any Error>) {
        let state = Self.cardState(for: result)
        panel.searchStatus = state
        if state == .saved {
            playSaveFeedback()
        }
        searchStatusResetTask?.cancel()
        searchStatusResetTask = .afterDelay(Motion.feedbackDuration) { [weak self] in
            self?.panel.searchStatus = nil
        }
    }

    @ObservationIgnored
    private var searchStatusResetTask: Task<Void, Never>?

    /// On any `.failure` but `ClipboardAccessDenied`, `saveClipboard` has logged the error.
    private static func cardState(for result: Result<SaveResult, any Error>) -> SaveCardState {
        switch result {
        case .success(.saved): .saved
        case .success(.alreadySaved): .alreadySaved
        case .success(.empty): .nothingToSave
        case .failure(is ClipboardAccessDenied): .accessDenied
        case .failure: .failed
        }
    }

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

    /// Switches to another notes folder: creates it if it's missing, stores its path, loads its notes,
    /// and moves the folder watcher to it. If the folder can't be created, this throws and the old
    /// folder stays active.
    func setFolder(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        defaults.set(url.path(percentEncoded: false), forKey: Preferences.notesFolderPathKey)
        store = NotesStore(folder: url)
        startWatching(url)
        // "Copied" belongs to a note of the old folder, and the clipboard may count as saved now.
        panel.copiedNote = nil
        refreshSaveCard()
    }

    /// The size of the shape's body (without the outward top corners) in the current mode. `PanelView`
    /// draws it, and `NotchPanelController` hit-tests against it.
    var shapeSize: CGSize {
        switch panel.mode {
        case .closed:
            panel.closedSize
        case .open:
            CGSize(
                width: PanelLayout.panelWidth,
                height: PanelLayout.recentPanelHeight(rowCount: min(store.notes.count, PanelLayout.recentCount))
            )
        case .search:
            PanelLayout.searchSize
        case .feedback:
            CGSize(width: PanelLayout.panelWidth, height: PanelLayout.feedbackPanelHeight)
        }
    }

    // MARK: - Context menu (#6)

    /// Closes the panel. Set by `NotchPanelController`, which owns the window.
    @ObservationIgnored
    var closePanel: () -> Void = {}

    /// Opens the note's file in the default app for `.md`, then closes the panel.
    /// If no app handles `.md`, macOS shows its own app chooser.
    func openInEditor(_ note: Note) {
        NSWorkspace.shared.open(note.fileURL)
        closePanel()
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
