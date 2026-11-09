import CryptoKit
import Foundation

/// Turns a note into Markdown with frontmatter and back, and builds its filename. Used only by `NotesStore`.
enum NoteFile {
    static let noteType = "text"

    /// 8 lowercase hex characters from a random `UInt32`.
    static func makeID() -> String {
        let hex = String(UInt32.random(in: .min ... .max), radix: 16)
        return String(repeating: "0", count: 8 - hex.count) + hex
    }

    /// ISO-8601 with seconds and offset in `timeZone`. UTC is written as `Z`.
    static func createdString(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }

    /// The exact file content: frontmatter, then the body untouched. No trailing newline is added.
    static func contents(noteID: String, created: Date, timeZone: TimeZone, body: String) -> Data {
        let header = "---\nid: \(noteID)\ncreated: \(createdString(created, timeZone: timeZone))\ntype: \(noteType)\n---\n"
        return Data((header + body).utf8)
    }

    /// Why a file in the notes folder isn't shown as a note.
    enum SkipReason: String, Error {
        case notUTF8 = "not valid UTF-8"
        case empty = "empty"
        case emptyBody = "body is empty"
        case unsupportedType = "type isn't text"
    }

    /// Reads any Markdown file in the notes folder. Frontmatter is optional; a missing or invalid `id`
    /// falls back to `fallbackID(for:)`, `created` to `fileDate()`, and `type` to `text`.
    /// `fileDate` is only called when it's needed. Never writes to the file.
    static func note(from data: Data, fileURL: URL, fileDate: () -> Date?) -> Result<Note, SkipReason> {
        guard let text = String(data: data, encoding: .utf8) else { return .failure(.notUTF8) }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .failure(.empty) }

        var fields: [String: String] = [:]
        var body = Substring(text)
        if let (parsed, rest) = frontmatter(of: text) {
            guard !rest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .failure(.emptyBody) }
            fields = parsed
            body = rest
        }

        // Other types are reserved for later versions, so they're skipped rather than shown as text.
        guard (fields["type"] ?? "").isEmpty || fields["type"] == noteType else { return .failure(.unsupportedType) }
        let noteID = fields["id"].flatMap { $0.isEmpty ? nil : $0 } ?? fallbackID(for: fileURL)
        let created = fields["created"].flatMap { createdParser.date(from: $0) } ?? fileDate() ?? .distantPast
        return .success(Note(noteID: noteID, created: created, type: noteType, body: String(body), fileURL: fileURL))
    }

    /// Shared because `reload()` parses one date per file. `ISO8601DateFormatter` is thread-safe.
    nonisolated(unsafe) private static let createdParser = ISO8601DateFormatter()

    /// The fields between a leading `---` line and the next `---` line, and everything after the
    /// closing line's line break. `nil` when the text doesn't start with frontmatter: no `---` first
    /// line, no closing `---`, or no `key: value` line in between. Such a file is plain Markdown that
    /// may start with a horizontal rule (story 39), so it's read whole, as the body.
    /// Lines end at `\n` or `\r\n`, so a `---` line may have a trailing `\r`.
    private static func frontmatter(of text: String) -> (fields: [String: String], body: Substring)? {
        let lines = text.split(omittingEmptySubsequences: false) { $0 == "\n" || $0 == "\r\n" }
        guard lines.first == "---", let close = lines.dropFirst().firstIndex(of: "---") else { return nil }
        var fields: [String: String] = [:]
        for line in lines[1 ..< close] {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            guard isFieldKey(key) else { continue }
            fields[key] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        guard !fields.isEmpty else { return nil }
        let closingEnd = lines[close].endIndex
        let bodyStart = closingEnd < text.endIndex ? text.index(after: closingEnd) : text.endIndex
        return (fields, text[bodyStart...])
    }

    /// A frontmatter key: one word of ASCII letters, digits, `_`, or `-`. Prose like
    /// `Note to self: …` between two horizontal rules isn't a field.
    private static func isFieldKey(_ key: String) -> Bool {
        !key.isEmpty && key.unicodeScalars.allSatisfy { scalar in
            scalar.isASCII && (scalar.properties.isAlphabetic || ("0"..."9").contains(scalar) || scalar == "_" || scalar == "-")
        }
    }

    /// The first 8 hex characters of the SHA-256 of the filename, so it's the same on every load.
    static func fallbackID(for fileURL: URL) -> String {
        let digest = SHA256.hash(data: Data(fileURL.lastPathComponent.utf8))
        return digest.prefix(4).map { String(format: "%02x", $0) }.joined()
    }

    /// Newest `created` first; ties broken by filename, descending, so the order is always the same.
    static func isOrderedBefore(_ lhs: Note, _ rhs: Note) -> Bool {
        if lhs.created != rhs.created { return lhs.created > rhs.created }
        return lhs.fileURL.lastPathComponent > rhs.fileURL.lastPathComponent
    }

    /// A free file URL in `folder` named `yyyy-MM-dd-HHmm-<slug>.md`, from `created` in `timeZone`.
    /// If the name is taken, `-2`, `-3`, … is inserted before `.md`.
    static func availableURL(in folder: URL, created: Date, timeZone: TimeZone, body: String) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        let base = "\(formatter.string(from: created))-\(slug(for: body))"

        var url = folder.appending(path: "\(base).md", directoryHint: .notDirectory)
        var suffix = 2
        while FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            url = folder.appending(path: "\(base)-\(suffix).md", directoryHint: .notDirectory)
            suffix += 1
        }
        return url
    }

    /// The title line before it's cut: the first line that isn't blank and isn't only a code fence,
    /// with leading `#` heading markers and surrounding whitespace removed. `nil` if no line qualifies.
    static func titleLine(of body: String) -> String? {
        splitAtTitleLine(body)?.title
    }

    /// The text after the title line with every whitespace run collapsed to one space, trimmed,
    /// and cut to 140 characters. Empty when nothing follows the title line.
    static func preview(of body: String) -> String {
        guard let rest = splitAtTitleLine(body)?.rest else { return "" }
        let words = rest.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        return String(words.joined(separator: " ").prefix(140))
    }

    /// The title line and everything after it.
    private static func splitAtTitleLine(_ body: String) -> (title: String, rest: Substring)? {
        for line in body.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || isCodeFence(trimmed) { continue }
            let title = trimmed.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
            if !title.isEmpty { return (title, body[line.endIndex...]) }
        }
        return nil
    }

    /// The title line cut at 80 characters with a trailing `…`, or `Untitled`.
    static func title(of body: String) -> String {
        guard let line = titleLine(of: body) else { return "Untitled" }
        return line.count > 80 ? line.prefix(80) + "…" : line
    }

    /// Lowercase ASCII, hyphenated, at most 50 characters. `note` when nothing is left.
    static func slug(for body: String) -> String {
        let latin = (titleLine(of: body) ?? "")
            .applyingTransform(.toLatin, reverse: false)?
            .applyingTransform(.stripDiacritics, reverse: false) ?? ""
        var slug = ""
        for scalar in latin.lowercased().unicodeScalars {
            if ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar) {
                slug.unicodeScalars.append(scalar)
            } else if !slug.isEmpty, !slug.hasSuffix("-") {
                slug.append("-")
            }
        }
        slug = String(slug.trimmingCharacters(in: ["-"]).prefix(50))
        slug = slug.trimmingCharacters(in: ["-"])
        return slug.isEmpty ? "note" : slug
    }

    /// A line that is only ```` ``` ```` or `~~~`, optionally followed by a language.
    private static func isCodeFence(_ line: String) -> Bool {
        guard line.hasPrefix("```") || line.hasPrefix("~~~") else { return false }
        let language = line.drop { $0 == "`" || $0 == "~" }
        return !language.contains(where: \.isWhitespace)
    }
}
