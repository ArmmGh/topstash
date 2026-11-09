import Foundation
import Testing

@testable import Topstash

/// `AppModel.searchResults`, which the search list and the shape's height share and which is kept
/// between reads: it must follow the query and the notes.
@MainActor
struct SearchResultsTests {
    let temp = TemporaryFolder()

    func makeAppModel(clipboard: FakeClipboard) -> AppModel {
        let defaults = UserDefaults(suiteName: "TopstashTests-\(UUID().uuidString)")!
        defaults.set(temp.url.path(percentEncoded: false), forKey: Preferences.notesFolderPathKey)
        return AppModel(defaults: defaults, clipboard: clipboard)
    }

    @Test func resultsFollowTheQuery() {
        let clipboard = FakeClipboard(text: "Buy milk")
        let appModel = makeAppModel(clipboard: clipboard)
        _ = appModel.saveClipboard()
        clipboard.text = "Call the bank"
        _ = appModel.saveClipboard()

        appModel.panel.query = "milk"
        #expect(appModel.searchResults.map(\.title) == ["Buy milk"])

        appModel.panel.query = "bank"
        #expect(appModel.searchResults.map(\.title) == ["Call the bank"])
    }

    @Test func resultsFollowNewNotes() {
        let clipboard = FakeClipboard(text: "Buy milk")
        let appModel = makeAppModel(clipboard: clipboard)
        _ = appModel.saveClipboard()
        appModel.panel.query = "buy"
        #expect(appModel.searchResults.count == 1)

        clipboard.text = "Buy bread"
        _ = appModel.saveClipboard()

        #expect(appModel.searchResults.count == 2)
    }
}
