import Foundation
import Testing
@testable import Topstash

/// The named actions views use to change the panel (`PanelActions`), on a controller that was never
/// started, so no window exists. What the window and focus do is checked by hand.
@MainActor
struct PanelActionsTests {
    let temp = TemporaryFolder()

    func makeController() -> (NotchPanelController, PanelModel) {
        let defaults = UserDefaults(suiteName: "TopstashTests-\(UUID().uuidString)")!
        defaults.set(temp.url.path(percentEncoded: false), forKey: Preferences.notesFolderPathKey)
        let appModel = AppModel(defaults: defaults, clipboard: FakeClipboard(text: nil))
        return (NotchPanelController(appModel: appModel), appModel.panel)
    }

    @Test func showAllOpensSearch() {
        let (controller, panel) = makeController()
        panel.mode = .open

        controller.showAll()

        #expect(panel.mode == .search)
    }

    @Test func closeSearchClosesThePanelAndClearsTheQuery() {
        let (controller, panel) = makeController()
        panel.mode = .open
        controller.showAll()
        panel.query = "milk"

        controller.closeSearch()

        #expect(panel.mode == .closed)
        #expect(panel.query == "")
    }

    @Test func closeSearchOutsideSearchLeavesThePanelOpen() {
        let (controller, panel) = makeController()
        panel.mode = .open

        controller.closeSearch()

        #expect(panel.mode == .open)
    }

    @Test func dismissAfterActionClosesTheOpenPanel() {
        let (controller, panel) = makeController()
        panel.mode = .open

        controller.dismissAfterAction()

        #expect(panel.mode == .closed)
    }

    @Test func dismissAfterActionClosesSearch() {
        let (controller, panel) = makeController()
        panel.mode = .open
        controller.showAll()

        controller.dismissAfterAction()

        #expect(panel.mode == .closed)
    }
}
