import Foundation
import Testing

@testable import Topstash

/// The named actions views use to change the panel (`PanelActions`), on a controller that was never
/// started, so no window exists. What the window and focus do is checked by hand.
@MainActor
struct PanelActionsTests {
    let temp = TemporaryFolder()

    let scheduler = ManualScheduler()

    func makeController() -> (NotchPanelController, PanelModel) {
        let defaults = UserDefaults(suiteName: "TopstashTests-\(UUID().uuidString)")!
        defaults.set(temp.url.path(percentEncoded: false), forKey: Preferences.notesFolderPathKey)
        let appModel = AppModel(defaults: defaults, clipboard: FakeClipboard(text: nil))
        return (NotchPanelController(appModel: appModel, schedule: scheduler.schedule), appModel.panel)
    }

    @Test func openSearchOpensSearch() {
        let (controller, panel) = makeController()
        panel.mode = .open

        controller.openSearch()

        #expect(panel.mode == .search)
    }

    @Test func closeSearchClosesThePanelAndClearsTheQuery() {
        let (controller, panel) = makeController()
        panel.mode = .open
        controller.openSearch()
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
        controller.openSearch()

        controller.dismissAfterAction()

        #expect(panel.mode == .closed)
    }

    // MARK: - Closing after a copy

    @Test func dismissAfterCopyClosesOnceCopiedHasShown() {
        let (controller, panel) = makeController()
        panel.mode = .open

        controller.dismissAfterCopy()
        scheduler.advance(by: Motion.copiedCloseDelay - 0.01)
        #expect(panel.mode == .open)

        scheduler.advance(by: 0.01)
        #expect(panel.mode == .closed)
    }

    @Test func dismissAfterCopyClosesSearch() {
        let (controller, panel) = makeController()
        panel.mode = .open
        controller.openSearch()

        controller.dismissAfterCopy()
        scheduler.advance(by: Motion.copiedCloseDelay)

        #expect(panel.mode == .closed)
    }

    @Test func anotherCopyRestartsTheWait() {
        let (controller, panel) = makeController()
        panel.mode = .open

        controller.dismissAfterCopy()
        scheduler.advance(by: Motion.copiedCloseDelay - 0.1)
        controller.dismissAfterCopy()
        scheduler.advance(by: Motion.copiedCloseDelay - 0.01)
        #expect(panel.mode == .open)

        scheduler.advance(by: 0.01)
        #expect(panel.mode == .closed)
    }

    @Test func changingModeBeforeTheCloseCancelsIt() {
        let (controller, panel) = makeController()
        panel.mode = .open

        controller.dismissAfterCopy()
        controller.openSearch()
        scheduler.advance(by: Motion.copiedCloseDelay)

        #expect(panel.mode == .search)
    }
}
