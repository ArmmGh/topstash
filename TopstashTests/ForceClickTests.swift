import Foundation
import Testing
import TopstashCore

@testable import Topstash

/// Force click on a row (`PanelModel.forceClick(buttonIsDown:)`): it peeks the hovered row once per
/// press, whether the Look up hook, pressure stage 2, or both report it, and the press's mouse-up
/// doesn't copy. A three-finger tap has no press, so it never holds back a copy.
@MainActor
struct ForceClickTests {
    let temp = TemporaryFolder()

    func makePanel(notes: [String]) throws -> (PanelModel, [Note]) {
        let defaults = UserDefaults(suiteName: "TopstashTests-\(UUID().uuidString)")!
        defaults.set(temp.url.path(percentEncoded: false), forKey: Preferences.notesFolderPathKey)
        let appModel = AppModel(defaults: defaults, clipboard: FakeClipboard(text: nil))
        let saved = try notes.map { text in
            guard case .saved(let note) = try appModel.store.save(text) else { throw CocoaError(.fileWriteUnknown) }
            return note
        }
        appModel.panel.mode = .open
        return (appModel.panel, saved)
    }

    @Test func forceClickPeeksTheHoveredRowAndItsMouseUpDoesNotCopy() throws {
        let (panel, notes) = try makePanel(notes: ["A\none", "B\ntwo"])
        panel.hover(notes[1], true)

        panel.pressBegan()
        panel.forceClick(buttonIsDown: true)

        #expect(panel.peekedNote == notes[1].id)
        #expect(panel.consumeCopySuppression(notes[1].id))
        // Only that one mouse-up: the next click copies.
        #expect(!panel.consumeCopySuppression(notes[1].id))
    }

    @Test func lookUpAndStageTwoInOnePressToggleOnce() throws {
        let (panel, notes) = try makePanel(notes: ["A\none"])
        panel.hover(notes[0], true)

        panel.pressBegan()
        panel.forceClick(buttonIsDown: true)
        panel.forceClick(buttonIsDown: true)
        #expect(panel.peekedNote == notes[0].id)

        // The next force click collapses it.
        panel.pressBegan()
        panel.forceClick(buttonIsDown: true)
        panel.forceClick(buttonIsDown: true)
        #expect(panel.peekedNote == nil)
    }

    @Test func threeFingerTapsToggleEachTimeAndTheNextClickCopies() throws {
        let (panel, notes) = try makePanel(notes: ["A\none"])
        panel.hover(notes[0], true)

        panel.forceClick(buttonIsDown: false)
        #expect(panel.peekedNote == notes[0].id)
        #expect(!panel.consumeCopySuppression(notes[0].id))

        panel.forceClick(buttonIsDown: false)
        #expect(panel.peekedNote == nil)
    }

    @Test func forceClickOffTheRowsDoesNothing() throws {
        let (panel, notes) = try makePanel(notes: ["A\none"])
        panel.hover(notes[0], true)
        panel.hover(notes[0], false)

        panel.pressBegan()
        panel.forceClick(buttonIsDown: true)

        #expect(panel.peekedNote == nil)
        #expect(!panel.consumeCopySuppression(notes[0].id))
    }

    @Test func leavingTheLastRowAfterEnteringTheNextKeepsTheNext() throws {
        let (panel, notes) = try makePanel(notes: ["A\none", "B\ntwo"])
        panel.hover(notes[0], true)
        panel.hover(notes[1], true)
        panel.hover(notes[0], false)

        panel.pressBegan()
        panel.forceClick(buttonIsDown: true)

        #expect(panel.peekedNote == notes[1].id)
    }

    @Test func aForceClickReleasedOffTheRowDoesNotEatTheNextClick() throws {
        let (panel, notes) = try makePanel(notes: ["A\none"])
        panel.hover(notes[0], true)
        panel.pressBegan()
        panel.forceClick(buttonIsDown: true)
        // Its mouse-up landed elsewhere, so the row's action never ran.

        panel.pressBegan()

        #expect(!panel.consumeCopySuppression(notes[0].id))
    }

    @Test func aModeChangeForgetsTheHoveredRow() throws {
        let (panel, notes) = try makePanel(notes: ["A\none"])
        panel.hover(notes[0], true)

        panel.mode = .closed
        panel.mode = .open
        panel.forceClick(buttonIsDown: false)

        #expect(panel.peekedNote == nil)
    }
}
