import Foundation
import Testing

@testable import Topstash

/// Saving the clipboard (`AppModel.saveClipboard`) and how each result shows on the save card and
/// as the search view's status.
@MainActor
struct ClipboardSaveTests {
    let temp = TemporaryFolder()

    func makeAppModel(clipboard: FakeClipboard, folder: URL? = nil) -> AppModel {
        let defaults = UserDefaults(suiteName: "TopstashTests-\(UUID().uuidString)")!
        defaults.set((folder ?? temp.url).path(percentEncoded: false), forKey: Preferences.notesFolderPathKey)
        return AppModel(defaults: defaults, clipboard: clipboard)
    }

    // MARK: - What a save returns

    @Test func unsavedTextIsSavedWithItsNote() {
        let appModel = makeAppModel(clipboard: FakeClipboard(text: "Buy milk"))

        let result = appModel.saveClipboard()

        guard case .saved(let note) = result else {
            Issue.record("Expected .saved, got \(result)")
            return
        }
        #expect(note.body == "Buy milk")
        #expect(appModel.store.notes == [note])
    }

    @Test func textInTheStoreIsAlreadySaved() throws {
        let appModel = makeAppModel(clipboard: FakeClipboard(text: "Buy milk"))
        try appModel.store.save("Buy milk")

        #expect(appModel.saveClipboard() == .alreadySaved)
    }

    @Test(arguments: [nil, " \n\t "])
    func noTextOrWhitespaceIsNothingToSave(text: String?) {
        let appModel = makeAppModel(clipboard: FakeClipboard(text: text))

        #expect(appModel.saveClipboard() == .nothingToSave)
    }

    @Test func textThatCannotBeReadIsAccessDenied() {
        let appModel = makeAppModel(clipboard: FakeClipboard(text: "Buy milk", access: .denied))

        #expect(appModel.saveClipboard() == .accessDenied)
    }

    @Test func aWriteErrorIsFailed() throws {
        // A file where the notes folder should be: the folder can't be created or written to.
        let blocked = temp.url.appending(path: "not-a-folder")
        try Data().write(to: blocked)
        let appModel = makeAppModel(clipboard: FakeClipboard(text: "Buy milk"), folder: blocked)

        #expect(appModel.saveClipboard() == .failed)
    }

    // MARK: - On the save card

    @Test func savedShowsTheCheckmarkAndPlaysTheFeedback() {
        let appModel = makeAppModel(clipboard: FakeClipboard(text: "Buy milk"))
        let result = appModel.saveClipboard()

        appModel.showSaveResult(result)

        #expect(appModel.panel.saveCard == .saved)
        #expect(appModel.panel.saveCount == 1)
    }

    @Test(arguments: [
        (ClipboardSaveResult.alreadySaved, SaveCardState.alreadySaved),
        (.nothingToSave, .nothingToSave),
        (.accessDenied, .accessDenied),
        (.failed, .failed),
    ])
    func otherResultsShowTheirCardWithoutTheFeedback(result: ClipboardSaveResult, card: SaveCardState) {
        let appModel = makeAppModel(clipboard: FakeClipboard(text: "Buy milk"))

        appModel.showSaveResult(result)

        #expect(appModel.panel.saveCard == card)
        #expect(appModel.panel.saveCount == 0)
    }

    @Test(arguments: [
        (ClipboardSaveResult.nothingToSave, 1.0 as Double?),
        (.failed, 2),
        // Already the clipboard's own state, so there's nothing to return to.
        (.alreadySaved, nil),
        (.accessDenied, nil),
    ])
    func transientResultsRevertToTheClipboardAfterTheirTime(result: ClipboardSaveResult, delay: Double?) {
        #expect(result.cardRevertDelay == delay)
    }

    @Test func savedRevertsOnceTheSaveFeedbackHasPlayed() {
        let appModel = makeAppModel(clipboard: FakeClipboard(text: "Buy milk"))

        #expect(appModel.saveClipboard().cardRevertDelay == 0.6)
    }

    // MARK: - As the search view's status

    @Test(arguments: [ClipboardSaveResult.alreadySaved, .nothingToSave, .accessDenied, .failed])
    func searchShowsTheResultAsItsStatus(result: ClipboardSaveResult) {
        let appModel = makeAppModel(clipboard: FakeClipboard(text: "Buy milk"))

        appModel.showSaveResultInSearch(result)

        #expect(appModel.panel.searchStatus == result)
        #expect(appModel.panel.saveCount == 0)
    }

    @Test func searchShowsSavedAndPlaysTheFeedback() {
        let appModel = makeAppModel(clipboard: FakeClipboard(text: "Buy milk"))
        let result = appModel.saveClipboard()

        appModel.showSaveResultInSearch(result)

        #expect(appModel.panel.searchStatus == result)
        #expect(appModel.panel.saveCount == 1)
    }
}
