import Testing
import TopstashCore

/// `SearchSnippet`: the search row's preview line around the first match, with the query's words to bold.
struct SearchSnippetTests {
    private func bolded(_ snippet: SearchSnippet) -> [String] {
        snippet.matches.map { String(snippet.text[$0]) }
    }

    @Test func aMatchNearTheStartShowsThePreviewFromItsStart() {
        let snippet = SearchSnippet(body: "Title\nFind one seam and test through it", query: "seam")

        #expect(snippet.text == "Find one seam and test through it")
        #expect(bolded(snippet) == ["seam"])
    }

    @Test func aMatchDeepInTheBodyStartsAtAWordBeforeItWithAnEllipsis() {
        let filler = (1...40).map { "word\($0)" }.joined(separator: " ")
        let snippet = SearchSnippet(body: "Title\n\(filler) needle and more text", query: "needle")

        #expect(snippet.text.hasPrefix("…"))
        #expect(snippet.text.contains("needle and more text"))
        #expect(bolded(snippet) == ["needle"])
        // Starts on a whole word, a few words before the match.
        let lead = snippet.text.dropFirst().prefix { $0 != " " }
        #expect(filler.split(separator: " ").contains(lead))
        #expect(snippet.text.distance(from: snippet.text.startIndex, to: snippet.matches[0].lowerBound) <= 1 + 24)
    }

    @Test func everyWordOfTheQueryIsBoldWhereverItAppears() {
        let snippet = SearchSnippet(body: "Title\na test at the seam, then another test", query: "seam test")

        #expect(bolded(snippet) == ["test", "seam", "test"])
    }

    @Test func matchingIgnoresCaseAndBoldsTheNotesOwnCasing() {
        let snippet = SearchSnippet(body: "Title\nRefactor the Payment module", query: "PAYMENT refactor")

        #expect(bolded(snippet) == ["Refactor", "Payment"])
    }

    @Test func partialWordsMatchLikeSearch() {
        let snippet = SearchSnippet(body: "Title\nRefactor this module", query: "factor")

        #expect(bolded(snippet) == ["factor"])
    }

    @Test(arguments: ["", "   "])
    func anEmptyQueryShowsTheNormalPreview(query: String) {
        let body = "Title\n  first   line\n\nsecond line"
        let snippet = SearchSnippet(body: body, query: query)

        #expect(snippet.text == "first line second line")
        #expect(snippet.matches.isEmpty)
    }

    @Test func aMatchOnlyInTheTitleShowsTheNormalPreview() {
        let snippet = SearchSnippet(body: "Needle title\nthe rest of the note", query: "needle")

        #expect(snippet.text == "the rest of the note")
        #expect(snippet.matches.isEmpty)
    }

    @Test func theSnippetIsOneLine() {
        let snippet = SearchSnippet(body: "Title\nfirst\n\n  second\tneedle\nthird", query: "needle")

        #expect(snippet.text == "first second needle third")
    }

    @Test func overlappingWordsBoldOneRange() {
        let snippet = SearchSnippet(body: "Title\nrefactoring", query: "refactor factoring")

        #expect(bolded(snippet) == ["refactoring"])
    }

    @Test func aOneLineNoteHasNoSnippet() {
        let snippet = SearchSnippet(body: "Only a title with the needle", query: "needle")

        #expect(snippet.text.isEmpty)
        #expect(snippet.matches.isEmpty)
    }
}
