import Foundation
import Observation

public enum SaveResult: Equatable, Sendable {
    case saved(Note)
    /// The text was already saved. Holds the existing note; nothing was written.
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

    /// The notes whose body contains every whitespace-separated term of `query`, in any order and
    /// ignoring case (not diacritics). Partial words match. Newest first, like `notes`.
    public func search(_ query: String) -> [Note] {
        let terms = query.split(whereSeparator: \.isWhitespace)
        return notes.filter { note in
            terms.allSatisfy { note.body.range(of: $0, options: .caseInsensitive) != nil }
        }
    }

    /// Saves `text` exactly as given to a new note file, creating the folder if it's missing.
    /// Empty or whitespace-only text returns `.empty`, and text that `contains` finds returns
    /// `.alreadySaved` with the existing note; neither writes anything. Folder and write errors are thrown.
    @discardableResult
    public func save(_ text: String) throws -> SaveResult {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .empty }
        if let existing = existingNote(for: text) { return .alreadySaved(existing) }
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

    // MARK: - Duplicates (#3)

    /// Whether a note already holds `text`, ignoring only leading and trailing whitespace and newlines.
    /// Text that trims to empty never matches.
    public func contains(_ text: String) -> Bool {
        existingNote(for: text) != nil
    }

    /// The newest note whose body equals `text` after trimming both. A linear scan over `notes`.
    private func existingNote(for text: String) -> Note? {
        let trimmed = Self.trimmed(text)
        guard !trimmed.isEmpty else { return nil }
        return notes.first { Self.trimmed($0.body) == trimmed }
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
