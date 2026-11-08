import Foundation
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
}
