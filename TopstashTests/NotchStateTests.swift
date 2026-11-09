import AppKit
import Testing

@testable import Topstash

/// The notch's open/close rules (`NotchState`) without windows: two screens side by side, each with
/// a hover area at its top center, and the visible shape of an open panel hanging below screen 1's.
@MainActor
struct NotchStateTests {
    static let screen1: CGDirectDisplayID = 1
    static let screen2: CGDirectDisplayID = 2
    let areas = [
        HoverArea(displayID: screen1, rect: NSRect(x: 700, y: 950, width: 200, height: 32), isNotch: true),
        HoverArea(displayID: screen2, rect: NSRect(x: 2500, y: 950, width: 200, height: 24), isNotch: false),
    ]
    /// The open panel's shape on screen 1, below its hover area.
    let shape = NSRect(x: 600, y: 700, width: 400, height: 282)

    let overArea1 = NSPoint(x: 800, y: 960)
    let overArea2 = NSPoint(x: 2600, y: 960)
    let overShape1 = NSPoint(x: 800, y: 750)
    let elsewhere = NSPoint(x: 100, y: 100)

    func surroundings(
        _ cursor: NSPoint, mode: PanelModel.Mode = .closed, menuOpen: Bool = false, areas: [HoverArea]? = nil
    ) -> NotchSurroundings {
        NotchSurroundings(
            cursor: cursor, hoverAreas: areas ?? self.areas, visibleShape: shape, mode: mode, isMenuTracking: menuOpen
        )
    }

    // MARK: - Hover delay

    @Test func hoveringStartsTheDelayAndItsEndOpensThePanel() {
        var state = NotchState.idle

        #expect(state.mouseMoved(surroundings(overArea1)) == [.startHoverDelay(Self.screen1)])
        #expect(state == .hovering(Self.screen1, fadingOn: nil))

        #expect(state.hoverDelayEnded(on: Self.screen1) == [.open(Self.screen1)])
        #expect(state == .shown(Self.screen1))
    }

    @Test func movingWithinTheHoverAreaKeepsTheRunningDelay() {
        var state = NotchState.hovering(Self.screen1, fadingOn: nil)

        #expect(state.mouseMoved(surroundings(NSPoint(x: 710, y: 955))) == [])
        #expect(state == .hovering(Self.screen1, fadingOn: nil))
    }

    @Test func leavingTheHoverAreaCancelsThePendingOpen() {
        var state = NotchState.hovering(Self.screen1, fadingOn: nil)

        #expect(state.mouseMoved(surroundings(elsewhere)) == [.cancelHoverDelay])
        #expect(state == .idle)
        // A delay that ends anyway, cancelled too late, opens nothing.
        #expect(state.hoverDelayEnded(on: Self.screen1) == [])
        #expect(state == .idle)
    }

    @Test func hoveringAnotherScreenRestartsTheDelayThere() {
        var state = NotchState.hovering(Self.screen1, fadingOn: nil)

        #expect(state.mouseMoved(surroundings(overArea2)) == [.startHoverDelay(Self.screen2)])
        #expect(state == .hovering(Self.screen2, fadingOn: nil))
        #expect(state.hoverDelayEnded(on: Self.screen1) == [])
        #expect(state.hoverDelayEnded(on: Self.screen2) == [.open(Self.screen2)])
        #expect(state == .shown(Self.screen2))
    }

    // MARK: - Closing

    @Test func theOpenPanelStaysOpenWhileTheCursorIsOverItsShapeOrHoverArea() {
        var state = NotchState.shown(Self.screen1)

        #expect(state.mouseMoved(surroundings(overShape1, mode: .open)) == [])
        #expect(state.mouseMoved(surroundings(overArea1, mode: .open)) == [])
        #expect(state == .shown(Self.screen1))
    }

    @Test func leavingTheOpenPanelClosesItAndTheAnimationEndOrdersItOut() {
        var state = NotchState.shown(Self.screen1)

        #expect(state.mouseMoved(surroundings(elsewhere, mode: .open)) == [.close])
        #expect(state == .closing(Self.screen1))
        #expect(state.mouseMoved(surroundings(elsewhere)) == [])

        #expect(state.closeAnimationEnded() == [.orderOut])
        #expect(state == .idle)
    }

    @Test func leavingForAnotherScreensHoverAreaClosesThePanel() {
        var state = NotchState.shown(Self.screen1)

        #expect(state.mouseMoved(surroundings(overArea2, mode: .open)) == [.close])
        #expect(state == .closing(Self.screen1))
    }

    @Test func theCursorComingBackDuringTheCloseAnimationReopensThePanel() {
        var state = NotchState.closing(Self.screen1)

        #expect(state.mouseMoved(surroundings(overShape1)) == [.switchToOpen])
        #expect(state == .shown(Self.screen1))
        // The cancelled animation ending late doesn't order the panel out.
        #expect(state.closeAnimationEnded() == [])
    }

    @Test func hoveringAnotherScreenDuringTheCloseAnimationStartsItsDelay() {
        var state = NotchState.closing(Self.screen1)

        #expect(state.mouseMoved(surroundings(overArea2)) == [.startHoverDelay(Self.screen2)])
        #expect(state == .hovering(Self.screen2, fadingOn: Self.screen1))

        #expect(state.closeAnimationEnded() == [.orderOut])
        #expect(state == .hovering(Self.screen2, fadingOn: nil))
    }

    @Test func theDelayEndingDuringTheCloseAnimationOpensOnTheHoveredScreen() {
        var state = NotchState.hovering(Self.screen2, fadingOn: Self.screen1)

        #expect(state.hoverDelayEnded(on: Self.screen2) == [.open(Self.screen2)])
        #expect(state == .shown(Self.screen2))
    }

    @Test func comingBackToTheFadingPanelWhileADelayRunsReopensItAndDropsTheDelay() {
        var state = NotchState.hovering(Self.screen2, fadingOn: Self.screen1)

        #expect(state.mouseMoved(surroundings(overShape1)) == [.cancelHoverDelay, .switchToOpen])
        #expect(state == .shown(Self.screen1))
    }

    @Test func leavingAnotherScreensHoverAreaDuringTheCloseAnimationKeepsClosing() {
        var state = NotchState.hovering(Self.screen2, fadingOn: Self.screen1)

        #expect(state.mouseMoved(surroundings(elsewhere)) == [.cancelHoverDelay])
        #expect(state == .closing(Self.screen1))
    }

    // MARK: - Dismissed

    @Test func aDismissedPanelStaysClosedUntilTheCursorLeavesTheHoverAreaAndShape() {
        var state = NotchState.shown(Self.screen1)

        #expect(state.dismiss() == [.close])
        #expect(state == .dismissed(fadingOn: Self.screen1))
        // Still over the fading panel: no reopen, no hover delay.
        #expect(state.mouseMoved(surroundings(overShape1)) == [])
        #expect(state.mouseMoved(surroundings(overArea1)) == [])
        #expect(state == .dismissed(fadingOn: Self.screen1))

        #expect(state.closeAnimationEnded() == [.orderOut])
        #expect(state == .dismissed(fadingOn: nil))
        #expect(state.mouseMoved(surroundings(overArea1)) == [])
        #expect(state == .dismissed(fadingOn: nil))

        #expect(state.mouseMoved(surroundings(elsewhere)) == [])
        #expect(state == .idle)
        // From then on, hovering opens it again.
        #expect(state.mouseMoved(surroundings(overArea1)) == [.startHoverDelay(Self.screen1)])
    }

    @Test func hoveringAnotherScreenWhileDismissedDoesNotOpen() {
        var state = NotchState.dismissed(fadingOn: nil)

        #expect(state.mouseMoved(surroundings(overArea2)) == [])
        #expect(state == .dismissed(fadingOn: nil))
    }

    @Test func leavingWhileStillFadingEndsTheDismissalButKeepsClosing() {
        var state = NotchState.dismissed(fadingOn: Self.screen1)

        #expect(state.mouseMoved(surroundings(elsewhere)) == [])
        #expect(state == .closing(Self.screen1))
        // Coming back now reopens it, like any close.
        #expect(state.mouseMoved(surroundings(overShape1)) == [.switchToOpen])
    }

    // MARK: - Search, menus, and the shortcut's feedback

    @Test func searchStaysOpenWhenTheCursorLeaves() {
        var state = NotchState.shown(Self.screen1)

        #expect(state.mouseMoved(surroundings(elsewhere, mode: .search)) == [])
        #expect(state.mouseMoved(surroundings(overArea2, mode: .search)) == [])
        #expect(state == .shown(Self.screen1))
    }

    @Test func mouseMovesAreIgnoredWhileAMenuIsOpen() {
        var shown = NotchState.shown(Self.screen1)
        #expect(shown.mouseMoved(surroundings(elsewhere, mode: .open, menuOpen: true)) == [])
        #expect(shown == .shown(Self.screen1))

        var idle = NotchState.idle
        #expect(idle.mouseMoved(surroundings(overArea1, menuOpen: true)) == [])
        #expect(idle == .idle)

        var closing = NotchState.closing(Self.screen1)
        #expect(closing.mouseMoved(surroundings(overShape1, menuOpen: true)) == [])
        #expect(closing == .closing(Self.screen1))
    }

    @Test func theMenuClosingWithTheCursorOutsideClosesThePanel() {
        var state = NotchState.shown(Self.screen1)

        // The controller re-runs the mouse-move decision when the menu closes.
        #expect(state.mouseMoved(surroundings(elsewhere, mode: .open, menuOpen: false)) == [.close])
    }

    @Test func theShortcutsFeedbackIgnoresMouseMoves() {
        var state = NotchState.shown(Self.screen1)

        #expect(state.mouseMoved(surroundings(elsewhere, mode: .feedback)) == [])
        #expect(state == .shown(Self.screen1))
    }

    @Test func theFeedbackEndingOverThePanelOpensIt() {
        var state = NotchState.shown(Self.screen1)

        #expect(state.feedbackEnded(surroundings(overShape1, mode: .feedback)) == [.switchToOpen])
        #expect(state == .shown(Self.screen1))
    }

    @Test func theFeedbackEndingAwayFromThePanelClosesIt() {
        var state = NotchState.shown(Self.screen1)

        #expect(state.feedbackEnded(surroundings(elsewhere, mode: .feedback)) == [.close])
        #expect(state == .closing(Self.screen1))
    }

    @Test func theFeedbackEndingAfterLeavingFeedbackDoesNothing() {
        var state = NotchState.shown(Self.screen1)

        #expect(state.feedbackEnded(surroundings(elsewhere, mode: .open)) == [])
        #expect(state == .shown(Self.screen1))
    }

    // MARK: - Search shortcut

    @Test func theSearchShortcutOpensSearchOnTheScreenWithTheCursor() {
        var state = NotchState.idle

        #expect(state.toggleSearch(on: Self.screen2, mode: .closed) == [.openSearch(Self.screen2)])
        #expect(state == .shown(Self.screen2))
    }

    @Test func theSearchShortcutOpensSearchFromTheOpenPanelOrTheShortcutsFeedback() {
        for mode in [PanelModel.Mode.open, .feedback] {
            var state = NotchState.shown(Self.screen1)

            #expect(state.toggleSearch(on: Self.screen1, mode: mode) == [.openSearch(Self.screen1)])
            #expect(state == .shown(Self.screen1))
        }
    }

    @Test func theSearchShortcutDuringTheHoverDelayDropsTheDelay() {
        var state = NotchState.hovering(Self.screen1, fadingOn: nil)

        #expect(state.toggleSearch(on: Self.screen1, mode: .closed) == [.cancelHoverDelay, .openSearch(Self.screen1)])
        #expect(state == .shown(Self.screen1))
        #expect(state.hoverDelayEnded(on: Self.screen1) == [])
    }

    @Test func theSearchShortcutOpensSearchWhileThePanelIsClosingOrDismissed() {
        for start in [NotchState.closing(Self.screen1), .dismissed(fadingOn: Self.screen1), .dismissed(fadingOn: nil)] {
            var state = start

            #expect(state.toggleSearch(on: Self.screen1, mode: .closed) == [.openSearch(Self.screen1)])
            #expect(state == .shown(Self.screen1))
        }
    }

    @Test func theSearchShortcutClosesSearchAsADismissal() {
        var state = NotchState.shown(Self.screen1)

        #expect(state.toggleSearch(on: Self.screen1, mode: .search) == [.close])
        #expect(state == .dismissed(fadingOn: Self.screen1))
    }

    @Test func searchOpenedByTheShortcutStaysOpenAwayFromTheNotchAndEscClosesItForGood() {
        var state = NotchState.idle
        _ = state.toggleSearch(on: Self.screen1, mode: .closed)

        #expect(state.mouseMoved(surroundings(elsewhere, mode: .search)) == [])
        #expect(state == .shown(Self.screen1))

        // Esc: the cursor is away from the notch, so the next move ends the dismissal.
        #expect(state.dismiss() == [.close])
        #expect(state.mouseMoved(surroundings(elsewhere, mode: .closed)) == [])
        #expect(state == .closing(Self.screen1))
        #expect(state.closeAnimationEnded() == [.orderOut])
        #expect(state == .idle)
    }

    // MARK: - Screen changes

    @Test func aScreenChangeRePlacesTheOpenPanel() {
        var state = NotchState.shown(Self.screen1)

        #expect(state.screensChanged(surroundings(elsewhere, mode: .open)) == [.place(Self.screen1)])
        #expect(state == .shown(Self.screen1))
    }

    @Test func thePanelClosesAtOnceWhenItsScreenIsGone() {
        let remaining = [areas[1]]
        var state = NotchState.shown(Self.screen1)

        #expect(state.screensChanged(surroundings(elsewhere, mode: .open, areas: remaining)) == [.closeAtOnce])
        #expect(state == .idle)

        var closing = NotchState.closing(Self.screen1)
        #expect(closing.screensChanged(surroundings(elsewhere, mode: .closed, areas: remaining)) == [.closeAtOnce])
        #expect(closing == .idle)
    }

    @Test func searchClosedByItsScreenGoingAwayCountsAsDismissed() {
        var state = NotchState.shown(Self.screen1)

        #expect(state.screensChanged(surroundings(elsewhere, mode: .search, areas: [areas[1]])) == [.closeAtOnce])
        #expect(state == .dismissed(fadingOn: nil))
    }

    @Test func aScreenChangeCancelsThePendingOpen() {
        var state = NotchState.hovering(Self.screen2, fadingOn: nil)

        #expect(state.screensChanged(surroundings(elsewhere, mode: .closed)) == [.cancelHoverDelay])
        #expect(state == .idle)

        var fading = NotchState.hovering(Self.screen2, fadingOn: Self.screen1)
        #expect(
            fading.screensChanged(surroundings(elsewhere, mode: .closed)) == [.cancelHoverDelay, .place(Self.screen1)])
        #expect(fading == .closing(Self.screen1))
    }

    @Test func aScreenChangeWithoutAWindowDoesNothing() {
        var state = NotchState.idle

        #expect(state.screensChanged(surroundings(elsewhere, mode: .closed)) == [])
        #expect(state == .idle)
    }
}
