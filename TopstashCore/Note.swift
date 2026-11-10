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
    /// What the row's peek shows under the title: the text after the title line with its line
    /// breaks, starting with the full title line when the title was cut, and cut at `peekLength`
    /// characters with a trailing `…`. Empty for a one-line note.
    public var peekText: String { Self.peekText(of: body) }

    /// `peekText` for a note with this body, cut at `limit` characters.
    public static func peekText(of body: String, limit: Int = peekLength) -> String {
        NoteFile.peekText(of: body, limit: limit)
    }

    /// The longest peek, in characters. "Open in Editor" shows the rest.
    public static let peekLength = 10_000
}
