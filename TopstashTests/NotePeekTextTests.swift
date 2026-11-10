import Testing
import TopstashCore

/// `Note.peekText`: what a row's peek shows under its title line, raw, with its line breaks.
struct NotePeekTextTests {
    @Test func isTheRawTextAfterTheTitleLineWithItsLineBreaks() {
        let body = "Title\n\n  first line\nsecond   line\n\n- item\n"

        #expect(Note.peekText(of: body) == "  first line\nsecond   line\n\n- item")
    }

    @Test func isEmptyForAOneLineNote() {
        #expect(Note.peekText(of: "Just a title") == "")
        #expect(Note.peekText(of: "Just a title\n\n  \n") == "")
    }

    @Test func startsWithTheFullTitleLineWhenTheTitleWasCut() {
        let title = String(repeating: "a", count: 81)

        #expect(Note.peekText(of: "# \(title)\nrest") == "\(title)\nrest")
    }

    @Test func aTitleOfEightyCharactersIsNotRepeated() {
        let title = String(repeating: "a", count: 80)

        #expect(Note.peekText(of: "\(title)\nrest") == "rest")
    }

    @Test func isCutAtTheLimitEndingInAnEllipsis() {
        let body = "Title\n" + String(repeating: "x", count: 30)

        #expect(Note.peekText(of: body, limit: 10) == String(repeating: "x", count: 10) + "…")
        #expect(Note.peekText(of: body, limit: 30) == String(repeating: "x", count: 30))
    }

    @Test func theDefaultLimitIsAboutTenThousandCharacters() {
        let peek = Note.peekText(of: "Title\n" + String(repeating: "x", count: 20_000))

        #expect(peek.count == 10_001)
        #expect(peek.hasSuffix("…"))
    }
}
