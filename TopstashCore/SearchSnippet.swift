import Foundation

/// A search result's preview line: the note's text around the first match, on one line, with the
/// ranges of the query's words to show in bold. Matching follows `NotesStore.search`: every
/// whitespace-separated word, ignoring case, partial words included.
public struct SearchSnippet: Equatable, Sendable {
    /// One line. Starts with `…` when it starts after the note's preview does.
    public let text: String
    /// Every place a query word appears in `text`, in order; overlapping matches are merged.
    public let matches: [Range<String.Index>]

    /// About how many characters of context come before the first match.
    static let leadingContext = 24
    /// The text after `body`'s title line, starting a few words before the query's first match.
    /// The normal preview, with nothing bold, when the query is empty or matches only the title.
    public init(body: String, query: String) {
        let words = NotesStore.searchWords(of: query)
        // The whole text, not just its first `previewLength` characters, so a match deep in the note is found.
        let line = NoteFile.textAfterTitleLine(of: body).map { NoteFile.collapsingWhitespace($0) } ?? ""
        let firstMatch = words.compactMap { line.range(of: $0, options: NotesStore.searchOptions)?.lowerBound }.min()
        guard let firstMatch else {
            text = String(line.prefix(NoteFile.previewLength))
            matches = []
            return
        }
        let start = Self.start(of: line, before: firstMatch)
        text = (start > line.startIndex ? "…" : "") + line[start...].prefix(NoteFile.previewLength)
        matches = Self.ranges(of: words, in: text)
    }

    /// `leadingContext` characters before `match`, moved forward to the start of a word unless that
    /// would pass the match.
    private static func start(of line: String, before match: String.Index) -> String.Index {
        guard let start = line.index(match, offsetBy: -leadingContext, limitedBy: line.startIndex),
            start > line.startIndex
        else { return line.startIndex }
        guard line[line.index(before: start)] != " ",
            let space = line[start..<match].firstIndex(of: " ")
        else { return start }
        return line.index(after: space)
    }

    private static func ranges(of words: [Substring], in text: String) -> [Range<String.Index>] {
        var found: [Range<String.Index>] = []
        for word in words {
            var searchStart = text.startIndex
            while let range = text.range(
                of: word, options: NotesStore.searchOptions, range: searchStart..<text.endIndex)
            {
                found.append(range)
                searchStart = range.upperBound
            }
        }
        found.sort { $0.lowerBound < $1.lowerBound }
        var merged: [Range<String.Index>] = []
        for range in found {
            if let last = merged.last, range.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }
        return merged
    }
}
