import Foundation

/// Turns a note into Markdown with frontmatter and builds its filename. Used only by `NotesStore`.
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
        for line in body.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || isCodeFence(trimmed) { continue }
            let title = trimmed.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
            if !title.isEmpty { return title }
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
