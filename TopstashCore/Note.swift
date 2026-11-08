import Foundation

/// One saved note. Its identity is the file, because frontmatter ids repeat if a user copies a file.
public struct Note: Identifiable, Hashable, Sendable {
    public var id: URL { fileURL }
    /// The frontmatter `id`.
    public let noteID: String
    public let created: Date
    /// `text` for now. Reserved for other note types.
    public let type: String
    /// The text exactly as saved.
    public let body: String
    public let fileURL: URL

    /// Derived from the body, never stored.
    public var title: String { NoteFile.title(of: body) }
    /// The text after the title line on one line, at most 140 characters. Empty for a one-line note.
    public var preview: String { NoteFile.preview(of: body) }

    init(noteID: String, created: Date, type: String, body: String, fileURL: URL) {
        self.noteID = noteID
        self.created = created
        self.type = type
        self.body = body
        self.fileURL = fileURL
    }
}
