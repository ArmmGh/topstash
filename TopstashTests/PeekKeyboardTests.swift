import Foundation
import Testing
import TopstashCore

@testable import Topstash

/// Peeking from the keyboard in search (`PanelModel.pressSpace(among:)`, `pressEscape()`): Space
/// toggles the selected result's peek only right after ↑/↓, ↑/↓ collapse it, and Esc closes it
/// before the panel.
@MainActor
struct PeekKeyboardTests {
    let temp = TemporaryFolder()

    /// A model in search with notes saved oldest first, and the results as search shows them.
    func makeSearch(notes: [String]) throws -> (PanelModel, [Note]) {
        let defaults = UserDefaults(suiteName: "TopstashTests-\(UUID().uuidString)")!
        defaults.set(temp.url.path(percentEncoded: false), forKey: Preferences.notesFolderPathKey)
        let appModel = AppModel(defaults: defaults, clipboard: FakeClipboard(text: nil))
        for text in notes { _ = try appModel.store.save(text) }
        appModel.panel.mode = .search
        return (appModel.panel, appModel.store.search(""))
    }

    let notes = ["Oldest\nbody", "Middle\nbody", "Newest\nbody"]

    @Test func spaceAfterDownPeeksTheSelectedResult() throws {
        let (panel, results) = try makeSearch(notes: notes)

        panel.moveSelection(by: 1, among: results.count)
        let handled = panel.pressSpace(among: results)

        #expect(handled)
        #expect(panel.peekedNote == results[1].id)
    }

    @Test func spaceWithoutUpOrDownTypesASpace() throws {
        let (panel, results) = try makeSearch(notes: notes)

        #expect(!panel.pressSpace(among: results))
        #expect(panel.peekedNote == nil)
    }

    @Test func anotherKeyAfterDownMakesSpaceTypeAgain() throws {
        let (panel, results) = try makeSearch(notes: notes)
        panel.moveSelection(by: 1, among: results.count)

        panel.pressOtherKey()

        #expect(!panel.pressSpace(among: results))
        #expect(panel.peekedNote == nil)
    }

    @Test func spaceAgainClosesThePeek() throws {
        let (panel, results) = try makeSearch(notes: notes)
        panel.moveSelection(by: 1, among: results.count)
        _ = panel.pressSpace(among: results)

        #expect(panel.pressSpace(among: results))
        #expect(panel.peekedNote == nil)
    }

    @Test(arguments: [1, -1])
    func upOrDownClosesThePeek(step: Int) throws {
        let (panel, results) = try makeSearch(notes: notes)
        panel.moveSelection(by: 1, among: results.count)
        _ = panel.pressSpace(among: results)

        panel.moveSelection(by: step, among: results.count)

        #expect(panel.peekedNote == nil)
    }

    @Test func escapeClosesThePeekFirstAndThenLetsThePanelClose() throws {
        let (panel, results) = try makeSearch(notes: notes)
        panel.moveSelection(by: 1, among: results.count)
        _ = panel.pressSpace(among: results)

        #expect(panel.pressEscape())
        #expect(panel.peekedNote == nil)
        #expect(!panel.pressEscape())
    }

    @Test func escapeWithoutAPeekLetsThePanelClose() throws {
        let (panel, _) = try makeSearch(notes: notes)

        #expect(!panel.pressEscape())
    }

    @Test func spaceTypesASpaceAfterSearchIsClosedAndOpenedAgain() throws {
        let (panel, results) = try makeSearch(notes: notes)
        panel.moveSelection(by: 1, among: results.count)

        panel.mode = .closed
        panel.mode = .search

        #expect(!panel.pressSpace(among: results))
    }

    @Test func spaceTypesASpaceAfterTheQueryChanges() throws {
        let (panel, results) = try makeSearch(notes: notes)
        panel.moveSelection(by: 1, among: results.count)

        panel.query = "body"

        #expect(!panel.pressSpace(among: results))
    }
}
