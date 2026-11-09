import Testing

@testable import Topstash

/// The keyboard selection in search: an index into the results that ↑/↓ move.
@MainActor
struct SearchSelectionTests {
    @Test func theFirstResultIsSelected() {
        let panel = PanelModel()

        #expect(panel.selectedResult(among: 3) == 0)
    }

    @Test func noResultsSelectNothing() {
        let panel = PanelModel()

        #expect(panel.selectedResult(among: 0) == nil)
    }

    @Test func downAndUpMoveTheSelection() {
        let panel = PanelModel()

        panel.moveSelection(by: 1, among: 3)
        panel.moveSelection(by: 1, among: 3)
        #expect(panel.selectedResult(among: 3) == 2)

        panel.moveSelection(by: -1, among: 3)
        #expect(panel.selectedResult(among: 3) == 1)
    }

    @Test func theSelectionStopsAtTheEnds() {
        let panel = PanelModel()

        panel.moveSelection(by: -1, among: 3)
        #expect(panel.selectedResult(among: 3) == 0)

        for _ in 0..<5 { panel.moveSelection(by: 1, among: 3) }
        #expect(panel.selectedResult(among: 3) == 2)
    }

    @Test func changingTheQuerySelectsTheFirstResult() {
        let panel = PanelModel()
        panel.moveSelection(by: 1, among: 3)

        panel.query = "milk"

        #expect(panel.selectedResult(among: 3) == 0)
    }

    @Test func settingTheSameQueryKeepsTheSelection() {
        let panel = PanelModel()
        panel.query = "milk"
        panel.moveSelection(by: 1, among: 3)

        // The field sets its text again on Return.
        panel.query = "milk"

        #expect(panel.selectedResult(among: 3) == 1)
    }

    @Test func closingSelectsTheFirstResultNextTime() {
        let panel = PanelModel()
        panel.mode = .search
        panel.moveSelection(by: 1, among: 3)

        panel.mode = .closed

        #expect(panel.selectedResult(among: 3) == 0)
    }

    @Test func fewerResultsKeepTheSelectionOnTheLast() {
        let panel = PanelModel()
        for _ in 0..<2 { panel.moveSelection(by: 1, among: 3) }

        // A note was deleted while searching.
        #expect(panel.selectedResult(among: 2) == 1)
        panel.moveSelection(by: -1, among: 2)
        #expect(panel.selectedResult(among: 2) == 0)
    }
}
