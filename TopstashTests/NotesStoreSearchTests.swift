import Foundation
import Testing
import TopstashCore

/// `NotesStore.search` (#5). Kept in its own file so it merges cleanly with other tickets' tests.
extension NotesStoreTests {
    @Test func searchReturnsNotesContainingEveryTermInAnyOrder() throws {
        let store = makeStore()
        let both = try savedNote(store.save("Refactor the payment module"))
        _ = try savedNote(store.save("Refactor the login screen"))
        _ = try savedNote(store.save("Payment receipts"))

        #expect(store.search("module refactor") == [both])
        #expect(store.search("refactor module") == [both])
    }

    @Test(arguments: ["refactor", "REFACTOR", "rEfAcToR", "Payment MODULE"])
    func searchIgnoresCase(query: String) throws {
        let store = makeStore()
        let note = try savedNote(store.save("Refactor the Payment module"))

        #expect(store.search(query) == [note])
    }

    @Test func searchFindsATermOnlyOnTheLastLineOfALongBody() throws {
        let store = makeStore()
        let lines = (1...500).map { "Line \($0) of filler text" } + ["needle at the very end"]
        let note = try savedNote(store.save(lines.joined(separator: "\n")))

        #expect(store.search("needle") == [note])
    }

    @Test func searchMatchesPartialWords() throws {
        let store = makeStore()
        let note = try savedNote(store.save("Refactor this module"))

        #expect(store.search("refac") == [note])
        #expect(store.search("factor dul") == [note])
    }

    @Test func searchWithNoMatchReturnsNothing() throws {
        let store = makeStore()
        _ = try savedNote(store.save("Refactor this module"))

        #expect(store.search("database").isEmpty)
        #expect(store.search("refactor database").isEmpty)
    }

    @Test func searchIgnoresCaseButNotDiacritics() throws {
        let store = makeStore()
        let note = try savedNote(store.save("Café au lait"))

        #expect(store.search("CAFÉ") == [note])
        #expect(store.search("cafe").isEmpty)
    }

    @Test(arguments: ["", " ", "\n", " \t\r\n  "])
    func emptyOrWhitespaceOnlySearchReturnsAllNotesNewestFirst(query: String) throws {
        let clock = Clock()
        let store = makeStore(clock: clock)
        let older = try savedNote(store.save("Older"))
        clock.advance(seconds: 60)
        let newer = try savedNote(store.save("Newer"))

        #expect(store.search(query) == [newer, older])
    }

    @Test func searchResultsAreNewestFirst() throws {
        let clock = Clock()
        let store = makeStore(clock: clock)
        // Saved oldest first; filenames ("a", "b", "c" slugs) would sort the other way round.
        let oldest = try savedNote(store.save("c prompt: oldest"))
        clock.advance(seconds: 10)
        _ = try savedNote(store.save("b unrelated"))
        clock.advance(seconds: 10)
        let newest = try savedNote(store.save("a prompt: newest"))

        #expect(store.search("prompt") == [newest, oldest])
        #expect(makeStore().search("PROMPT") == [newest, oldest])
    }

    @Test func searchSplitsTermsOnNewlinesAndTabs() throws {
        let store = makeStore()
        let note = try savedNote(store.save("Refactor this module"))
        _ = try savedNote(store.save("Refactor that screen"))

        #expect(store.search("refactor\nmodule") == [note])
        #expect(store.search("module\trefactor") == [note])
    }
}
