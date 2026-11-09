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
    /// Changed only by `setNotes(_:indexing:)`.
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

    /// Bumped by every change to `notes` and every background reload's start, so a background
    /// reload that started before either is dropped.
    @ObservationIgnored private var generation = 0
    /// Each trimmed body, mapped to the newest note holding it, for `existingNote(trimmed:)`.
    /// Built on first use; kept in step with `notes` by `setNotes(_:indexing:)`.
    @ObservationIgnored private var notesByTrimmedBody: [String: Note]?

    /// The one place `notes` changes. Bumps `generation`, so a background reload that started
    /// earlier is dropped, and keeps the duplicate index in step: `indexing` updates it for a change
    /// it can describe (a save adds one body), otherwise it's cleared and rebuilt on next use.
    private func setNotes(_ newNotes: [Note], indexing: ((inout [String: Note]) -> Void)? = nil) {
        generation += 1
        if let indexing, notesByTrimmedBody != nil {
            indexing(&notesByTrimmedBody!)
        } else {
            notesByTrimmedBody = nil
        }
        // Skipping an equal assignment keeps SwiftUI from redrawing for nothing.
        if newNotes != notes {
            notes = newNotes
        }
    }

    /// Reads the folder on the calling (main) thread. Used when the store is created, so `notes`
    /// is filled from the start; folder changes use `reloadInBackground()`.
    /// Assigns `notes` only when the result differs.
    public func reload() {
        setNotes(Self.loadNotes(in: folder))
    }

    /// Reads the folder off the main thread, then assigns `notes` unless a save, a delete, or a newer
    /// reload happened in the meantime (the file change behind it triggers another reload).
    /// The returned task finishes once the result is applied or dropped.
    @discardableResult
    public func reloadInBackground() -> Task<Void, Never> {
        generation += 1
        let started = generation
        let folder = folder
        return Task {
            let loaded = await Task.detached(priority: .userInitiated) { Self.loadNotes(in: folder) }.value
            guard started == generation else { return }
            setNotes(loaded)
        }
    }

    /// Every visible `.md` file in the top level of `folder`, newest first, skipping files that don't
    /// parse. A missing folder means no notes. An iCloud file whose contents aren't on this Mac
    /// (Optimize Mac Storage) is skipped and its download started, instead of blocking until it
    /// arrives; the download's file change reloads again.
    private nonisolated static func loadNotes(in folder: URL) -> [Note] {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey, .ubiquitousItemDownloadingStatusKey, .creationDateKey, .contentModificationDateKey,
        ]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: Array(keys),
            options: .skipsHiddenFiles
        )) ?? []
        var loaded: [Note] = []
        for url in urls where isNoteFile(named: url.lastPathComponent) {
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
            // A file without a `created` falls back to its creation date, else its modification date.
            let fileDate = { values?.creationDate ?? values?.contentModificationDate }
            switch NoteFile.note(from: data, fileURL: fileURL, fileDate: fileDate) {
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

    /// Whether a file in the top level of the folder is read as a note: a visible `.md` file.
    /// `FolderWatcher` uses it to ignore changes to anything else.
    public nonisolated static func isNoteFile(named name: String) -> Bool {
        !name.hasPrefix(".") && name.lowercased().hasSuffix(".md")
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
        let trimmed = Self.trimmed(text)
        guard !trimmed.isEmpty else { return .empty }
        if let existing = existingNote(trimmed: trimmed) { return .alreadySaved(existing) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // Whole seconds, so the note matches what the frontmatter stores.
        let created = Date(timeIntervalSince1970: now().timeIntervalSince1970.rounded(.down))
        let noteID = NoteFile.makeID()
        let fileURL = NoteFile.availableURL(in: folder, created: created, timeZone: timeZone, body: text)
        let data = NoteFile.contents(noteID: noteID, created: created, timeZone: timeZone, body: text)
        try data.write(to: fileURL, options: .atomic)
        let note = Note(noteID: noteID, created: created, body: text, fileURL: fileURL)
        var updated = notes
        updated.insert(note, at: notes.firstIndex { NoteFile.isOrderedBefore(note, $0) } ?? notes.endIndex)
        // No note held this text, so the index only gains the new note instead of being rebuilt.
        setNotes(updated) { $0[trimmed] = note }
        return .saved(note)
    }

    // MARK: - Deleting

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
        // Another note may hold the same text, so the index is rebuilt.
        setNotes(notes.filter { $0.id != note.id })
    }

    /// The default `trash`.
    public nonisolated static func moveToTrash(_ url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    // MARK: - Duplicates

    /// Whether a note already holds `text`, ignoring only leading and trailing whitespace and newlines.
    /// Text that trims to empty never matches.
    public func contains(_ text: String) -> Bool {
        existingNote(trimmed: Self.trimmed(text)) != nil
    }

    /// The newest note whose trimmed body equals `trimmed`, text already trimmed by the caller.
    private func existingNote(trimmed: String) -> Note? {
        guard !trimmed.isEmpty else { return nil }
        if notesByTrimmedBody == nil {
            var index: [String: Note] = [:]
            // `notes` is newest first, so the first note seen for a body is kept.
            for note in notes {
                let key = Self.trimmed(note.body)
                if index[key] == nil { index[key] = note }
            }
            notesByTrimmedBody = index
        }
        return notesByTrimmedBody?[trimmed]
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
