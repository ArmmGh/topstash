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

    /// How long a row shows "Copied".
    static let copiedDuration: Duration = .seconds(1.2)

    @ObservationIgnored
    private var copiedResetTask: Task<Void, Never>?
    @ObservationIgnored
    private let logger = Logger(subsystem: "io.github.armmgh.topstash", category: "AppModel")

    /// Creates the notes folder if it's missing.
    init(defaults: UserDefaults = .standard) {
        let folder = Preferences.notesFolder(defaults)
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
        panel.copiedNoteID = note.id
        copiedResetTask?.cancel()
        copiedResetTask = Task { [weak self] in
            try? await Task.sleep(for: Self.copiedDuration)
            guard !Task.isCancelled, let self else { return }
            self.panel.copiedNoteID = nil
        }
        // The clipboard now holds a saved note, so the card reads "Already saved".
        refreshSaveCard()
    }

    // MARK: - Save card (#3)

    /// How long the card shows "Saved" before it's refreshed.
    static let savedDuration: Duration = .seconds(1)
    /// How long the card shows "Couldn't save" before it's refreshed.
    static let failedDuration: Duration = .seconds(2)

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

    /// The save card's click. Shows the result of this save, not the state shown before the click,
    /// because the clipboard can change in between.
    func saveClipboardFromCard() {
        saveCardResetTask?.cancel()
        saveCardResetTask = nil
        switch saveClipboard() {
        case .success(.saved):
            showTransientSaveCard(.saved, for: Self.savedDuration)
        case .success(.alreadySaved):
            panel.saveCard = .alreadySaved
        case .success(.empty):
            // Also what a read denied at the paste privacy alert returns. The refresh afterwards
            // picks up `.accessDenied` if the user changed the setting.
            showTransientSaveCard(.nothingToSave, for: Self.savedDuration)
        case .failure:
            // `saveClipboard` logs the error.
            showTransientSaveCard(.failed, for: Self.failedDuration)
        }
    }

    private func showTransientSaveCard(_ state: SaveCardState, for duration: Duration) {
        panel.saveCard = state
        saveCardResetTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled, let self else { return }
            self.saveCardResetTask = nil
            self.refreshSaveCard()
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
