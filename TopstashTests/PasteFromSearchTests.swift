import Foundation
import Testing
import TopstashCore

@testable import Topstash

/// ⌥Return in search (`PanelActions.pasteFromSearch`), on a controller that was never started, so
/// no window exists. That the previous app receives the paste is checked by hand.
@MainActor
struct PasteFromSearchTests {
    let temp = TemporaryFolder()
    let clipboard = FakeClipboard(text: nil)
    let paster: FakePaster
    let appModel: AppModel
    let controller: NotchPanelController
    let note: Note

    init() throws {
        let defaults = UserDefaults(suiteName: "TopstashTests-\(UUID().uuidString)")!
        defaults.set(temp.url.path(percentEncoded: false), forKey: Preferences.notesFolderPathKey)
        paster = FakePaster()
        appModel = AppModel(defaults: defaults, clipboard: clipboard, paster: paster)
        controller = NotchPanelController(appModel: appModel)
        guard case .saved(let saved) = try appModel.store.save("Summarize this diff") else {
            throw CancellationError()
        }
        note = saved
        appModel.panel.mode = .open
        controller.openSearch()
    }

    var panel: PanelModel { appModel.panel }

    @Test func offByDefaultItCopiesAndClosesLikeReturn() {
        controller.pasteFromSearch(note)

        #expect(clipboard.text == "Summarize this diff")
        #expect(panel.mode == .closed)
        #expect(paster.pasteCount == 0)
    }

    @Test func offItNeverAsksForAccess() {
        paster.isAllowed = false

        controller.pasteFromSearch(note)

        #expect(paster.accessRequestCount == 0)
        #expect(panel.searchStatus == nil)
    }

    @Test func onWithAccessItCopiesClosesThenPastes() {
        appModel.pastesOnOptionReturn = true
        var modeAtPaste: PanelModel.Mode?
        var clipboardAtPaste: String?
        paster.onPaste = { [panel, clipboard] in
            modeAtPaste = panel.mode
            clipboardAtPaste = clipboard.text
        }

        controller.pasteFromSearch(note)

        #expect(paster.pasteCount == 1)
        #expect(modeAtPaste == .closed)
        #expect(clipboardAtPaste == "Summarize this diff")
    }

    @Test func onWithoutAccessItCopiesOnlyAndSaysWhy() {
        appModel.pastesOnOptionReturn = true
        paster.isAllowed = false

        controller.pasteFromSearch(note)

        #expect(clipboard.text == "Summarize this diff")
        #expect(paster.accessRequestCount == 1)
        #expect(paster.pasteCount == 0)
        #expect(panel.mode == .search)
        #expect(panel.searchStatus == .pasteNeedsAccess)
    }

    @Test func theAccessStatusClearsLikeTheShortcutsResult() {
        let scheduler = ManualScheduler()
        let defaults = UserDefaults(suiteName: "TopstashTests-\(UUID().uuidString)")!
        defaults.set(temp.url.path(percentEncoded: false), forKey: Preferences.notesFolderPathKey)
        let appModel = AppModel(
            defaults: defaults, clipboard: clipboard, paster: FakePaster(isAllowed: false),
            schedule: scheduler.schedule)
        let controller = NotchPanelController(appModel: appModel)
        appModel.pastesOnOptionReturn = true
        appModel.panel.mode = .open
        controller.openSearch()

        controller.pasteFromSearch(note)
        scheduler.advance(by: Motion.feedbackDuration)

        #expect(appModel.panel.searchStatus == nil)
    }

    @Test func theToggleIsStoredInTheDefaults() {
        let defaults = UserDefaults(suiteName: "TopstashTests-\(UUID().uuidString)")!
        defaults.set(temp.url.path(percentEncoded: false), forKey: Preferences.notesFolderPathKey)

        defaults.set(true, forKey: Preferences.pastesOnOptionReturnKey)

        #expect(AppModel(defaults: defaults, clipboard: clipboard, paster: paster).pastesOnOptionReturn)
    }

    @Test func outsideSearchItDoesNothing() {
        appModel.pastesOnOptionReturn = true
        controller.closeSearch()
        panel.mode = .open

        controller.pasteFromSearch(note)

        #expect(clipboard.text == nil)
        #expect(paster.pasteCount == 0)
        #expect(panel.mode == .open)
    }
}
