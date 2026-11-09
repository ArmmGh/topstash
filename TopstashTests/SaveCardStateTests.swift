import Foundation
import Testing

@testable import Topstash

/// The card chosen when the panel opens (`AppModel.refreshSaveCard`), which must never read the
/// clipboard's contents when that would show macOS's paste privacy alert.
@MainActor
struct SaveCardStateTests {
    let temp = TemporaryFolder()

    func makeAppModel(clipboard: FakeClipboard) -> AppModel {
        let defaults = UserDefaults(suiteName: "TopstashTests-\(UUID().uuidString)")!
        defaults.set(temp.url.path(percentEncoded: false), forKey: Preferences.notesFolderPathKey)
        return AppModel(defaults: defaults, clipboard: clipboard)
    }

    @Test func noTextIsNothingToSave() {
        let clipboard = FakeClipboard(text: nil)
        let appModel = makeAppModel(clipboard: clipboard)

        appModel.refreshSaveCard()

        #expect(appModel.panel.saveCard == .nothingToSave)
    }

    @Test func whitespaceOnlyTextIsNothingToSave() {
        let appModel = makeAppModel(clipboard: FakeClipboard(text: " \n\t "))

        appModel.refreshSaveCard()

        #expect(appModel.panel.saveCard == .nothingToSave)
    }

    @Test func unsavedTextIsPreviewedFromItsFirstVisibleCharacter() {
        let appModel = makeAppModel(clipboard: FakeClipboard(text: "\n\n  Buy milk\n  and eggs\n\n"))

        appModel.refreshSaveCard()

        // Lines after the first keep their indentation; the count is the full text's.
        #expect(appModel.panel.saveCard == .preview(text: "Buy milk\n  and eggs", characterCount: 25))
    }

    @Test func textAlreadyInTheStoreIsAlreadySaved() throws {
        let clipboard = FakeClipboard(text: "Buy milk")
        let appModel = makeAppModel(clipboard: clipboard)
        _ = try appModel.store.save("Buy milk")

        appModel.refreshSaveCard()

        #expect(appModel.panel.saveCard == .alreadySaved)
    }

    @Test func readingThatWouldPromptIsReadyWithoutPreview() {
        let clipboard = FakeClipboard(text: "Buy milk", access: .wouldPrompt)
        let appModel = makeAppModel(clipboard: clipboard)

        appModel.refreshSaveCard()

        #expect(appModel.panel.saveCard == .readyWithoutPreview)
    }

    @Test func deniedAccessIsAccessDenied() {
        let clipboard = FakeClipboard(text: "Buy milk", access: .denied)
        let appModel = makeAppModel(clipboard: clipboard)

        appModel.refreshSaveCard()

        #expect(appModel.panel.saveCard == .accessDenied)
    }

    @Test(arguments: [PasteAccess.wouldPrompt, .denied])
    func contentsAreNeverReadWhenReadingIsNotAllowed(access: PasteAccess) throws {
        let clipboard = FakeClipboard(text: "Buy milk", access: access)
        let appModel = makeAppModel(clipboard: clipboard)
        _ = try appModel.store.save("Buy milk")

        appModel.refreshSaveCard()
        clipboard.simulateCopy("Something new")
        appModel.refreshSaveCard()
        clipboard.simulateCopy(" ")
        appModel.refreshSaveCard()

        #expect(clipboard.readCount == 0)
    }

    @Test func textTheAppCopiedIsAlreadySavedWithoutReadingWhenReadingWouldPrompt() throws {
        let clipboard = FakeClipboard(text: nil, access: .wouldPrompt)
        let appModel = makeAppModel(clipboard: clipboard)
        guard case .saved(let note) = try appModel.store.save("Buy milk") else {
            Issue.record("The note wasn't saved")
            return
        }

        appModel.copy(note)

        #expect(appModel.panel.saveCard == .alreadySaved)
        #expect(clipboard.readCount == 0)
    }

    @Test func textTheAppSavedIsAlreadySavedWithoutReadingAgainWhenReadingWouldPrompt() {
        let clipboard = FakeClipboard(text: "Buy milk", access: .wouldPrompt)
        let appModel = makeAppModel(clipboard: clipboard)
        // A click on the card: the user asked to read, so the alert may show this once.
        _ = appModel.saveClipboard()
        let readsBySaving = clipboard.readCount

        appModel.refreshSaveCard()

        #expect(appModel.panel.saveCard == .alreadySaved)
        #expect(clipboard.readCount == readsBySaving)
    }

    @Test func knownTextNoLongerCountsOnceAnotherAppReplacesIt() throws {
        let clipboard = FakeClipboard(text: nil, access: .wouldPrompt)
        let appModel = makeAppModel(clipboard: clipboard)
        guard case .saved(let note) = try appModel.store.save("Buy milk") else {
            Issue.record("The note wasn't saved")
            return
        }
        appModel.copy(note)

        clipboard.simulateCopy("Buy milk")
        appModel.refreshSaveCard()

        #expect(appModel.panel.saveCard == .readyWithoutPreview)
    }
}
