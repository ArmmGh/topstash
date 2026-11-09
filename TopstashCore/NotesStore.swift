import Foundation
import Observation
import os

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

    /// Bumped by every change to `notes`, so a background reload that started before it is dropped.
    @ObservationIgnored private var generation = 0

    /// Reads the folder on the calling (main) thread. Used when the store is created, so `notes`
    /// is filled from the start; folder changes use `reloadInBackground()`.
    /// Assigns `notes` only when the result differs.
    public func reload() {
        generation += 1
        apply(Self.loadNotes(in: folder))
    }

    /// Reads the folder off the main thread, then assigns `notes` unless a save, a delete, or a newer
    /// reload happened in the meantime (the file change behind it triggers another reload).
    public func reloadInBackground() {
        generation += 1
        let started = generation
        let folder = folder
        Task {
            let loaded = await Task.detached(priority: .userInitiated) { Self.loadNotes(in: folder) }.value
            guard started == generation else { return }
            apply(loaded)
        }
    }

    private func apply(_ loaded: [Note]) {
        // Skipping an equal assignment keeps SwiftUI from redrawing for nothing.
        if loaded != notes {
            notes = loaded
        }
    }

    /// Every visible `.md` file in the top level of `folder`, newest first, skipping files that don't
    /// parse. A missing folder means no notes. An iCloud file whose contents aren't on this Mac
    /// (Optimize Mac Storage) is skipped and its download started, instead of blocking until it
    /// arrives; the download's file change reloads again.
    private nonisolated static func loadNotes(in folder: URL) -> [Note] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .ubiquitousItemDownloadingStatusKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: Array(keys),
            options: .skipsHiddenFiles
        )) ?? []
        var loaded: [Note] = []
        for url in urls where url.pathExtension.lowercased() == "md" {
            let values = try? url.resourceValues(forKeys: keys)
            guard values?.isRegularFile == true else { continue }
            // Built from `folder` so ids match the URLs `save` returns.
            let fileURL = folder.appending(path: url.lastPathComponent, directoryHint: .notDirectory)
            if let status = values?.ubiquitousItemDownloadingStatus, status != .current {
                try? FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
                logger.debug("Skipped \(fileURL.lastPathComponent, privacy: .public): not downloaded from iCloud yet")
                continue
            }
            guard let data = try? Data(contentsOf: fileURL) else { continue }
            switch NoteFile.note(from: data, fileURL: fileURL, fileDate: { fileDate(of: fileURL) }) {
            case .success(let note):
                loaded.append(note)
            case .failure(let reason):
                logger.debug("Skipped \(fileURL.lastPathComponent, privacy: .public): \(reason.rawValue, privacy: .public)")
            }
        }
        loaded.sort(by: NoteFile.isOrderedBefore)
        return loaded
    }

    private nonisolated static let logger = Logger(category: "NotesStore")

    /// The fallback `created` for a file without one: its creation date, else its modification date.
    private nonisolated static func fileDate(of url: URL) -> Date? {
        let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        return values?.creationDate ?? values?.contentModificationDate
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
        generation += 1
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
        generation += 1
        notes.removeAll { $0.id == note.id }
    }

    /// The default `trash`.
    public nonisolated static func moveToTrash(_ url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
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
