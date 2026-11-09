import Foundation
import Testing
import TopstashCore

@testable import Topstash

/// Return and ⌥Return in search (`PanelActions.copyFromSearch` and `pasteFromSearch`), on a
/// controller that was never started, so no window exists. That the previous app receives the
/// paste is checked by hand.
@MainActor
struct PasteFromSearchTests {
    let temp = TemporaryFolder()
    let clipboard = FakeClipboard(text: nil)
    let paster = FakePaster()
    let scheduler = ManualScheduler()

    /// A controller in search mode with one note, and the toggle set to `pastes`.
    func makeSearch(pastes: Bool = false) throws -> (NotchPanelController, AppModel, Note) {
        let defaults = UserDefaults(suiteName: "TopstashTests-\(UUID().uuidString)")!
        defaults.set(temp.url.path(percentEncoded: false), forKey: Preferences.notesFolderPathKey)
        defaults.set(pastes, forKey: Preferences.pastesOnOptionReturnKey)
        let appModel = AppModel(
            defaults: defaults, clipboard: clipboard, paster: paster, schedule: scheduler.schedule)
        let controller = NotchPanelController(appModel: appModel, schedule: scheduler.schedule)
        guard case .saved(let note) = try appModel.store.save("Summarize this diff") else {
            throw CocoaError(.fileWriteUnknown)
        }
        appModel.panel.mode = .open
        controller.openSearch()
        return (controller, appModel, note)
    }

    @Test func returnCopiesAndCloses() throws {
        let (controller, appModel, note) = try makeSearch()

        controller.copyFromSearch(note)

        #expect(clipboard.text == "Summarize this diff")
        #expect(appModel.panel.mode == .closed)
    }

    @Test func offByDefaultOptionReturnCopiesAndClosesLikeReturn() throws {
        let (controller, appModel, note) = try makeSearch()
        #expect(!appModel.pastesOnOptionReturn)

        controller.pasteFromSearch(note)

        #expect(clipboard.text == "Summarize this diff")
        #expect(appModel.panel.mode == .closed)
        #expect(paster.pasteCount == 0)
    }

    @Test func offItNeverAsksForAccess() throws {
        let (controller, appModel, note) = try makeSearch()
        paster.isAllowed = false

        controller.pasteFromSearch(note)

        #expect(paster.accessRequestCount == 0)
        #expect(appModel.panel.searchStatus == nil)
    }

    @Test func onWithAccessItCopiesClosesThenPastes() throws {
        let (controller, appModel, note) = try makeSearch(pastes: true)
        var modeAtPaste: PanelModel.Mode?
        var clipboardAtPaste: String?
        paster.onPaste = { [clipboard] in
            modeAtPaste = appModel.panel.mode
            clipboardAtPaste = clipboard.text
        }

        controller.pasteFromSearch(note)

        #expect(paster.pasteCount == 1)
        #expect(modeAtPaste == .closed)
        #expect(clipboardAtPaste == "Summarize this diff")
    }

    @Test func onWithoutAccessItCopiesOnlyAndSaysWhy() throws {
        let (controller, appModel, note) = try makeSearch(pastes: true)
        paster.isAllowed = false

        controller.pasteFromSearch(note)

        #expect(clipboard.text == "Summarize this diff")
        #expect(paster.accessRequestCount == 1)
        #expect(paster.pasteCount == 0)
        #expect(appModel.panel.mode == .search)
        #expect(appModel.panel.searchStatus == .pasteNeedsAccess)
    }

    @Test func theAccessStatusClearsLikeTheShortcutsResult() throws {
        let (controller, appModel, note) = try makeSearch(pastes: true)
        paster.isAllowed = false

        controller.pasteFromSearch(note)
        scheduler.advance(by: Motion.feedbackDuration)

        #expect(appModel.panel.searchStatus == nil)
    }

    @Test func outsideSearchNeitherKeyDoesAnything() throws {
        let (controller, appModel, note) = try makeSearch(pastes: true)
        controller.closeSearch()
        appModel.panel.mode = .open

        controller.copyFromSearch(note)
        controller.pasteFromSearch(note)

        #expect(clipboard.text == nil)
        #expect(paster.pasteCount == 0)
        #expect(appModel.panel.mode == .open)
    }
}
