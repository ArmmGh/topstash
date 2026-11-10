import Foundation
import Testing
import TopstashCore

@testable import Topstash

/// Which row peeks (`PanelModel.togglePeek`), and how the shape follows it (`AppModel.shapeSize`):
/// one peek at a time, none after the panel closes, and only a row that's shown makes the shape taller.
@MainActor
struct PeekStateTests {
    let temp = TemporaryFolder()

    /// A model with notes saved oldest first, in `mode`.
    func makeAppModel(_ mode: PanelModel.Mode, notes: [String]) throws -> (AppModel, [Note]) {
        let defaults = UserDefaults(suiteName: "TopstashTests-\(UUID().uuidString)")!
        defaults.set(temp.url.path(percentEncoded: false), forKey: Preferences.notesFolderPathKey)
        let appModel = AppModel(defaults: defaults, clipboard: FakeClipboard(text: nil))
        let saved = try notes.map { text in
            guard case .saved(let note) = try appModel.store.save(text) else { throw CocoaError(.fileWriteUnknown) }
            return note
        }
        appModel.panel.mode = mode
        return (appModel, saved)
    }

    /// Three lines after the title: 29 pt taller than a collapsed row.
    let threeLines = "Title\none\ntwo\nthree"

    @Test func togglingPeeksAndTogglingAgainCollapses() throws {
        let (appModel, notes) = try makeAppModel(.open, notes: [threeLines])
        let collapsed = appModel.shapeSize.height

        appModel.panel.togglePeek(notes[0])
        #expect(appModel.panel.peekedNote == notes[0].id)
        #expect(appModel.shapeSize.height == collapsed + 29)

        appModel.panel.togglePeek(notes[0])
        #expect(appModel.panel.peekedNote == nil)
        #expect(appModel.shapeSize.height == collapsed)
    }

    @Test func peekingAnotherRowCollapsesTheFirst() throws {
        let (appModel, notes) = try makeAppModel(.open, notes: [threeLines, "Short\nline"])
        let collapsed = appModel.shapeSize.height

        appModel.panel.togglePeek(notes[0])
        appModel.panel.togglePeek(notes[1])

        #expect(appModel.panel.peekedNote == notes[1].id)
        // The one-line peek is 1 pt taller than the collapsed row.
        #expect(appModel.shapeSize.height == collapsed + 1)
    }

    @Test func thePeekKeepsTheTextItShows() throws {
        let (appModel, notes) = try makeAppModel(.open, notes: [threeLines])

        appModel.panel.togglePeek(notes[0])

        #expect(appModel.panel.peek?.text == "one\ntwo\nthree")
    }

    @Test(arguments: [PanelModel.Mode.open, .search])
    func closingThePanelCollapsesThePeek(mode: PanelModel.Mode) throws {
        let (appModel, notes) = try makeAppModel(mode, notes: [threeLines])
        appModel.panel.togglePeek(notes[0])

        appModel.panel.mode = .closed
        appModel.panel.mode = mode

        #expect(appModel.panel.peekedNote == nil)
    }

    @Test func switchingBetweenTheListAndSearchCollapsesThePeek() throws {
        let (appModel, notes) = try makeAppModel(.open, notes: [threeLines])
        appModel.panel.togglePeek(notes[0])

        appModel.panel.mode = .search

        #expect(appModel.panel.peekedNote == nil)
    }

    @Test func aNewQueryCollapsesThePeek() throws {
        let (appModel, notes) = try makeAppModel(.search, notes: [threeLines])
        appModel.panel.togglePeek(notes[0])

        appModel.panel.query = "one"

        #expect(appModel.panel.peekedNote == nil)
    }

    @Test func aPeekedNoteThatIsNoLongerShownDoesNotGrowTheShape() throws {
        let (appModel, notes) = try makeAppModel(.open, notes: [threeLines, "Other"])
        let oneRowShorter = PanelLayout.shapeSize(for: appModel.panel, noteCount: 1).height
        appModel.panel.togglePeek(notes[0])

        try appModel.store.delete(notes[0])

        #expect(appModel.shapeSize.height == oneRowShorter)
    }

    @Test func aPeekInSearchGrowsTheSearchShape() throws {
        let (appModel, notes) = try makeAppModel(.search, notes: [threeLines])
        let collapsed = appModel.shapeSize.height

        appModel.panel.togglePeek(notes[0])

        #expect(appModel.shapeSize.height == collapsed + 29)
    }
}
