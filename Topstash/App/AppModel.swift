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

    /// Reloads the store whenever the folder changes on disk. Our own saves trigger a reload too,
    /// which is harmless: `reload()` assigns `notes` only when something changed.
    @ObservationIgnored
    private var watcher: FolderWatcher?

    /// Replaces the current watcher (#9 calls this when the folder changes).
    private func startWatching(_ folder: URL) {
        watcher?.stop()
        let watcher = FolderWatcher(folder: folder) { [weak self] in
            self?.store.reload()
        }
        watcher.start()
        self.watcher = watcher
    }

    /// Reads the clipboard and saves its text as a note.
    func saveClipboard() -> Result<SaveResult, any Error> {
        let text = clipboard.readText() ?? ""
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

    /// Sets the save card from the clipboard. Called when the panel opens, after `copy`,
    /// and when a transient "Saved" or "Couldn't save" ends.
    /// Reads the clipboard's contents only when that can't show the paste privacy alert (#4).
    func refreshSaveCard() {
        guard clipboard.hasText() else {
            panel.saveCard = .nothingToSave
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
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            panel.saveCard = .nothingToSave
        } else if store.contains(text) {
            panel.saveCard = .alreadySaved
        } else {
            panel.saveCard = .preview(text: text, characterCount: text.count)
        }
    }

    /// Shows a save's result on the card: the card's click, and the shortcut (#10).
    /// "Saved", "Nothing to save", and "Couldn't save" are transient: they revert to the clipboard's
    /// state after a moment, unless `reverts` is false (the shortcut's feedback panel, which hides
    /// or refreshes the card itself when its time is up).
    func showSaveResult(_ result: Result<SaveResult, any Error>, reverts: Bool = true) {
        saveCardResetTask?.cancel()
        saveCardResetTask = nil
        switch result {
        case .success(.saved):
            // The checkmark shows for the save feedback's length (#11), then the card returns.
            showSaveCard(.saved, revertingAfter: reverts ? Motion.saveFeedbackDuration : nil)
            playSaveFeedback()
        case .success(.alreadySaved):
            panel.saveCard = .alreadySaved
        case .success(.empty):
            // Also what a read denied at the paste privacy alert returns. The refresh afterwards
            // picks up `.accessDenied` if the user changed the setting.
            showSaveCard(.nothingToSave, revertingAfter: reverts ? Motion.nothingToSaveDuration : nil)
        case .failure:
            // `saveClipboard` logs the error.
            showSaveCard(.failed, revertingAfter: reverts ? Motion.failedDuration : nil)
        }
    }

    /// The haptic, and through `panel.saveCount` the checkmark bounce and the notch's gulp (#11).
    /// Here rather than in a view, so it plays however the save happened and whatever is on screen.
    private func playSaveFeedback() {
        panel.saveCount += 1
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }

    private func showSaveCard(_ state: SaveCardState, revertingAfter seconds: Double?) {
        panel.saveCard = state
        guard let seconds else { return }
        saveCardResetTask = .afterDelay(seconds) { [weak self] in
            self?.saveCardResetTask = nil
            self?.refreshSaveCard()
        }
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
        // Stops the old watcher first.
        startWatching(url)
        // "Copied" belongs to a note of the old folder, and the clipboard may count as saved now.
        panel.copiedNote = nil
        refreshSaveCard()
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
