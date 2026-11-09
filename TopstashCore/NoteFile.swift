import CryptoKit
import Foundation

/// Turns a note into Markdown with frontmatter and back, and builds its filename. Used only by `NotesStore`.
enum NoteFile {
    static let noteType = "text"

    /// 8 lowercase hex characters from a random `UInt32`.
    static func makeID() -> String {
        String(format: "%08x", UInt32.random(in: .min ... .max))
    }

    /// ISO-8601 with seconds and offset in `timeZone`, such as `+04:00`. UTC is written as `Z`.
    /// The colon offset separator is needed: the style's default writes `+0400`.
    static func createdString(_ date: Date, timeZone: TimeZone) -> String {
        date.formatted(Date.ISO8601FormatStyle(timeZoneSeparator: .colon, timeZone: timeZone))
    }

    /// The exact file content: frontmatter, then the body untouched. No trailing newline is added.
    static func contents(noteID: String, created: Date, timeZone: TimeZone, body: String) -> Data {
        let header =
            "---\nid: \(noteID)\ncreated: \(createdString(created, timeZone: timeZone))\ntype: \(noteType)\n---\n"
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
        // Stops at the first visible character, unlike trimming a copy of the whole file.
        guard !text.allSatisfy(\.isWhitespace) else { return .failure(.empty) }

        var fields: [String: String] = [:]
        var body = Substring(text)
        if let (parsed, rest) = frontmatter(of: text) {
            guard !rest.allSatisfy(\.isWhitespace) else { return .failure(.emptyBody) }
            fields = parsed
            body = rest
        }

        // Other types are reserved for later versions, so they're skipped rather than shown as text.
        guard (fields["type"] ?? "").isEmpty || fields["type"] == noteType else { return .failure(.unsupportedType) }
        let noteID = fields["id"].flatMap { $0.isEmpty ? nil : $0 } ?? fallbackID(for: fileURL)
        let created =
            fields["created"].flatMap { try? Date.ISO8601FormatStyle().parse($0) } ?? fileDate() ?? .distantPast
        return .success(Note(noteID: noteID, created: created, body: String(body), fileURL: fileURL))
    }

    /// The fields between a leading `---` line and the next `---` line, and everything after the
    /// closing line's line break. `nil` when the text doesn't start with frontmatter: no `---` first
    /// line, no closing `---`, or no `key: value` line in between. Such a file is plain Markdown that
    /// may start with a horizontal rule, so it's read whole, as the body.
    /// Lines end at `\n` or `\r\n`, so a `---` line may have a trailing `\r`.
    /// Reads lines only up to the closing `---`, not the whole body.
    private static func frontmatter(of text: String) -> (fields: [String: String], body: Substring)? {
        var fields: [String: String] = [:]
        var lineStart = text.startIndex
        var isFirstLine = true
        while lineStart < text.endIndex {
            let lineEnd = text[lineStart...].firstIndex { $0 == "\n" || $0 == "\r\n" } ?? text.endIndex
            let line = text[lineStart..<lineEnd]
            let nextLineStart = lineEnd < text.endIndex ? text.index(after: lineEnd) : text.endIndex
            if isFirstLine {
                guard line == "---" else { return nil }
                isFirstLine = false
            } else if line == "---" {
                return fields.isEmpty ? nil : (fields, text[nextLineStart...])
            } else if let colon = line.firstIndex(of: ":") {
                let key = line[..<colon].trimmingCharacters(in: .whitespaces)
                if isFieldKey(key) {
                    fields[key] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                }
            }
            lineStart = nextLineStart
        }
        return nil
    }

    /// A frontmatter key: one word of ASCII letters, digits, `_`, or `-`. Prose like
    /// `Note to self: …` between two horizontal rules isn't a field.
    private static func isFieldKey(_ key: String) -> Bool {
        !key.isEmpty
            && key.unicodeScalars.allSatisfy { scalar in
                scalar.isASCII
                    && (scalar.properties.isAlphabetic || ("0"..."9").contains(scalar) || scalar == "_"
                        || scalar == "-")
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
    /// Stops reading at the 140th character, so a long note costs no more than a short one.
    static func preview(of body: String) -> String {
        guard let rest = splitAtTitleLine(body)?.rest else { return "" }
        let limit = 140
        var preview = ""
        var count = 0
        var spaceBefore = false
        for character in rest {
            if character.isWhitespace {
                spaceBefore = !preview.isEmpty
                continue
            }
            if spaceBefore {
                guard count < limit else { break }
                preview.append(" ")
                count += 1
                spaceBefore = false
            }
            guard count < limit else { break }
            preview.append(character)
            count += 1
        }
        return preview
    }

    /// The title line and everything after it. Reads lines only up to the title line.
    private static func splitAtTitleLine(_ body: String) -> (title: String, rest: Substring)? {
        var lineStart = body.startIndex
        while lineStart < body.endIndex {
            let lineEnd = body[lineStart...].firstIndex(where: \.isNewline) ?? body.endIndex
            let trimmed = body[lineStart..<lineEnd].trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty, !isCodeFence(trimmed) {
                let title = trimmed.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
                if !title.isEmpty { return (title, body[lineEnd...]) }
            }
            lineStart = lineEnd < body.endIndex ? body.index(after: lineEnd) : body.endIndex
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
        let latin =
            (titleLine(of: body) ?? "")
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
        // No leading `-` is ever added; a trailing one may be left, or exposed by the cut.
        slug = String(slug.prefix(50)).trimmingCharacters(in: ["-"])
        return slug.isEmpty ? "note" : slug
    }

    /// A line that is only ```` ``` ```` or `~~~`, optionally followed by a language.
    private static func isCodeFence(_ line: String) -> Bool {
        guard line.hasPrefix("```") || line.hasPrefix("~~~") else { return false }
        let language = line.drop { $0 == "`" || $0 == "~" }
        return !language.contains(where: \.isWhitespace)
    }
}
