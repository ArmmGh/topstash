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

    public init(folder: URL, now: @escaping () -> Date = Date.init, timeZone: TimeZone = .current) {
        self.folder = folder
        self.now = now
        self.timeZone = timeZone
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
        notes.insert(note, at: 0)
        return .saved(note)
    }
}
