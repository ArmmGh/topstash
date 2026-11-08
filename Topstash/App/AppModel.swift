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
    }
}
