import Foundation
import Testing
import TopstashCore

@testable import Topstash

/// How long "Copied", a save result on the card, and the search status stay before reverting,
/// measured on a `ManualScheduler` instead of real time.
@MainActor
struct FeedbackTimingTests {
    let temp = TemporaryFolder()
    let scheduler = ManualScheduler()

    func makeAppModel(clipboard: FakeClipboard) -> AppModel {
        let defaults = UserDefaults(suiteName: "TopstashTests-\(UUID().uuidString)")!
        defaults.set(temp.url.path(percentEncoded: false), forKey: Preferences.notesFolderPathKey)
        return AppModel(defaults: defaults, clipboard: clipboard, schedule: scheduler.schedule)
    }

    func savedNote(_ text: String, in appModel: AppModel) throws -> Note {
        guard case .saved(let note) = try appModel.store.save(text) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return note
    }

    @Test func copiedShowsForItsDurationThenClears() throws {
        let appModel = makeAppModel(clipboard: FakeClipboard(text: nil))
        let note = try savedNote("Buy milk", in: appModel)

        appModel.copy(note)
        scheduler.advance(by: Motion.copiedDuration - 0.01)
        #expect(appModel.panel.copiedNote == note.id)

        scheduler.advance(by: 0.02)
        #expect(appModel.panel.copiedNote == nil)
    }

    /// Every copy bumps the count, even of the row already showing "Copied", so its checkmark
    /// bounces again.
    @Test func everyCopyCountsSoTheCheckmarkBouncesAgain() throws {
        let appModel = makeAppModel(clipboard: FakeClipboard(text: nil))
        let note = try savedNote("Buy milk", in: appModel)

        appModel.copy(note)
        appModel.copy(note)

        #expect(appModel.panel.copyCount == 2)
    }

    @Test func copyingAnotherNoteRestartsCopied() throws {
        let appModel = makeAppModel(clipboard: FakeClipboard(text: nil))
        let first = try savedNote("Buy milk", in: appModel)
        let second = try savedNote("Call mom", in: appModel)

        appModel.copy(first)
        scheduler.advance(by: Motion.copiedDuration / 2)
        appModel.copy(second)
        scheduler.advance(by: Motion.copiedDuration - 0.01)
        #expect(appModel.panel.copiedNote == second.id)

        scheduler.advance(by: 0.02)
        #expect(appModel.panel.copiedNote == nil)
    }

    @Test func savedRevertsToTheClipboardsStateAfterItsDelay() throws {
        let clipboard = FakeClipboard(text: "Buy milk")
        let appModel = makeAppModel(clipboard: clipboard)
        let result = appModel.saveClipboard()
        let delay = try #require(result.cardRevertDelay)

        appModel.showSaveResult(result)
        scheduler.advance(by: delay - 0.01)
        #expect(appModel.panel.saveCard == result.cardState)

        scheduler.advance(by: 0.02)
        #expect(appModel.panel.saveCard == .alreadySaved)
    }

    @Test func aNewResultRestartsTheCardsRevert() throws {
        let appModel = makeAppModel(clipboard: FakeClipboard(text: "Buy milk"))
        let delay = try #require(ClipboardSaveResult.failed.cardRevertDelay)

        appModel.showSaveResult(.failed)
        scheduler.advance(by: delay / 2)
        appModel.showSaveResult(.failed)
        scheduler.advance(by: delay - 0.01)
        #expect(appModel.panel.saveCard == .failed)

        scheduler.advance(by: 0.02)
        #expect(appModel.panel.saveCard == .preview(text: "Buy milk", characterCount: 8))
    }

    @Test func theCardBeforeASaveCancelsAPendingRevert() {
        let appModel = makeAppModel(clipboard: FakeClipboard(text: nil))

        appModel.showSaveResult(.failed)
        appModel.showCardBeforeSave(of: "Buy milk")
        scheduler.advance(by: 60)

        #expect(appModel.panel.saveCard == .preview(text: "Buy milk", characterCount: 8))
    }

    @Test func aResultThatDoesNotRevertStays() {
        let appModel = makeAppModel(clipboard: FakeClipboard(text: nil))

        appModel.showSaveResult(.failed, reverts: false)
        scheduler.advance(by: 60)

        #expect(appModel.panel.saveCard == ClipboardSaveResult.failed.cardState)
    }

    @Test func searchStatusClearsAfterTheFeedbackDurationAndRestartsOnAnotherResult() {
        let appModel = makeAppModel(clipboard: FakeClipboard(text: nil))

        appModel.showSaveResultInSearch(.nothingToSave)
        scheduler.advance(by: Motion.feedbackDuration / 2)
        appModel.showSaveResultInSearch(.failed)
        scheduler.advance(by: Motion.feedbackDuration - 0.01)
        #expect(appModel.panel.searchStatus == .saveResult(.failed))

        scheduler.advance(by: 0.02)
        #expect(appModel.panel.searchStatus == nil)
    }
}
