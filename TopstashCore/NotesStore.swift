import Foundation
import Observation

public enum SaveResult: Equatable, Sendable {
    case saved(Note)
    /// Returned from #3 on.
    case alreadySaved(Note)
    case empty
}

@MainActor @Observable
public final class NotesStore {
    public let folder: URL
    /// Newest first.
    public private(set) var notes: [Note] = []

    private let now: () -> Date
    private let timeZone: TimeZone
    private let trash: (URL) throws -> Void

    /// `trash` moves a file to the Trash. Tests pass their own, so they never touch the real Trash.
    public init(
        folder: URL,
        now: @escaping () -> Date = Date.init,
        timeZone: TimeZone = .current,
        trash: @escaping (URL) throws -> Void = NotesStore.moveToTrash
    ) {
        self.folder = folder
        self.now = now
        self.timeZone = timeZone
        self.trash = trash
        reload()
    }

    /// Reads every visible `.md` file in the top level of the folder, skipping files that don't parse.
    /// A missing folder means no notes. Assigns `notes` only when the result differs.
    public func reload() {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: .skipsHiddenFiles
        )) ?? []
        var loaded: [Note] = []
        for url in urls where url.pathExtension.lowercased() == "md" {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
            // Built from `folder` so ids match the URLs `save` returns.
            let fileURL = folder.appending(path: url.lastPathComponent, directoryHint: .notDirectory)
            guard let data = try? Data(contentsOf: fileURL),
                  let note = NoteFile.note(from: data, fileURL: fileURL)
            else { continue }
            loaded.append(note)
        }
        loaded.sort(by: NoteFile.isOrderedBefore)
        // Skipping an equal assignment keeps SwiftUI from redrawing for nothing.
        if loaded != notes {
            notes = loaded
        }
    }

    /// The newest notes, up to `limit`. Empty for a limit of 0 or less.
    public func recent(limit: Int) -> [Note] {
        Array(notes.prefix(max(limit, 0)))
    }

    /// Saves `text` exactly as given to a new note file, creating the folder if it's missing.
    /// Empty or whitespace-only text returns `.empty` and writes nothing. Folder and write errors are thrown.
    @discardableResult
    public func save(_ text: String) throws -> SaveResult {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .empty }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // Whole seconds, so the note matches what the frontmatter stores.
        let created = Date(timeIntervalSince1970: now().timeIntervalSince1970.rounded(.down))
        let noteID = NoteFile.makeID()
        let fileURL = NoteFile.availableURL(in: folder, created: created, timeZone: timeZone, body: text)
        let data = NoteFile.contents(noteID: noteID, created: created, timeZone: timeZone, body: text)
        try data.write(to: fileURL, options: .atomic)
        let note = Note(noteID: noteID, created: created, type: NoteFile.noteType, body: text, fileURL: fileURL)
        let index = notes.firstIndex { NoteFile.isOrderedBefore(note, $0) } ?? notes.endIndex
        notes.insert(note, at: index)
        return .saved(note)
    }

    // MARK: - Deleting (#6)

    /// Moves the note's file to the Trash and removes the note from `notes`.
    /// A file that's already gone only removes the note. Other errors are thrown, and the note stays.
    public func delete(_ note: Note) throws {
        do {
            try trash(note.fileURL)
        } catch where FileManager.default.fileExists(atPath: note.fileURL.path(percentEncoded: false)) {
            throw error
        } catch {
            // Already removed on disk: nothing to move.
        }
        notes.removeAll { $0.id == note.id }
    }

    /// The default `trash`.
    public nonisolated static func moveToTrash(_ url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }
}
