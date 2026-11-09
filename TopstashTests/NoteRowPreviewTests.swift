import SwiftUI
import Testing
import TopstashCore

@testable import Topstash

/// A search row's preview: the snippet's matches bold and full white, the rest in the row's style.
@MainActor
struct NoteRowPreviewTests {
    @Test func matchesAreBoldAndWhiteAndTheRestIsPlain() {
        let snippet = SearchSnippet(body: "Title\nfind one seam and test", query: "seam test")
        let preview = NoteRow.snippetText(snippet, matchColor: .white)

        #expect(String(preview.characters) == "find one seam and test")
        let runs = preview.runs.map {
            (String(preview[$0.range].characters), $0.swiftUI.font, $0.swiftUI.foregroundColor)
        }
        #expect(runs.map(\.0) == ["find one ", "seam", " and ", "test"])
        #expect(runs.map { $0.1 == PanelStyle.metaMatch } == [false, true, false, true])
        #expect(runs.map { $0.2 == .white } == [false, true, false, true])
    }
}
