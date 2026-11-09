import Foundation

/// One saved note. Its identity is the file, because frontmatter ids repeat if a user copies a file.
public struct Note: Identifiable, Hashable, Sendable {
    public var id: URL { fileURL }
    /// The frontmatter `id`.
    public let noteID: String
    public let created: Date
    /// `text` for now. Files of other types are skipped, so every note is text.
    public var type: String { NoteFile.noteType }
    /// The text exactly as saved.
    public let body: String
    public let fileURL: URL

    /// Derived from the body, never stored.
    public var title: String { NoteFile.title(of: body) }
    /// The text after the title line on one line, at most 140 characters. Empty for a one-line note.
    public var preview: String { NoteFile.preview(of: body) }
}
