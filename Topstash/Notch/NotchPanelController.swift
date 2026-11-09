import AppKit
import os
import TopstashCore

/// Tracks the mouse, applies the hover delay, and shows or hides the notch panel on the hovered screen.
@MainActor
final class NotchPanelController {
    private let appModel: AppModel
    private let logger = Logger(category: "NotchPanel")

    private var window: NotchPanel?
    /// Hands key status back to the frontmost app when search closes, without ordering `window` out.
    private let keyHandback = KeyHandbackPanel()
    /// One per connected screen.
    private var hoverAreas: [HoverArea] = []
    /// Hovering, shown, closing, dismissed: the rules live in `NotchState`; this class carries out its effects.
    private var state = NotchState.idle

    private var monitors: [Any] = []
    private var screenObserver: (any NSObjectProtocol)?
    /// Runs while `state` is `.hovering`.
    private let hoverDelay = DelayedAction()
    /// Runs while the close animation does: in `.closing`, or in `.hovering` and `.dismissed` with a fading window.
    private let closeAnimation = DelayedAction()
    /// Installed only while in search mode: closes the panel on a click outside or when it resigns key.
    private var searchMouseMonitor: Any?
    private var searchResignObserver: (any NSObjectProtocol)?
    private var menuObservers: [any NSObjectProtocol] = []
    /// True while any menu of the app is open.
    private var isMenuTracking = false
    /// Ends the shortcut's feedback (#10).
    /// The countdown, or before it the settle delay of a new save's feedback.
    private let feedback = DelayedAction()

    private var panel: PanelModel { appModel.panel }

    init(appModel: AppModel) {
        self.appModel = appModel
    }

    func start() {
        window = NotchPanel(rootView: PanelView(appModel: appModel, actions: self)) { [weak self] in
            self?.panel.mode == .search
        }
        rebuildHoverAreas()

        // Mouse-moved monitors don't need Accessibility permission, and they still see the cursor
        // when a full-screen app hides the menu bar. The local monitor covers the cursor being over
        // our own panel, where global events aren't delivered.
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseMoved() }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.mouseMoved() }
            return event
        }) {
            monitors.append(local)
        }

        // Displays added or removed, resolution or arrangement changed.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screensChanged() }
        }

        observeMenuTracking()
    }

    // MARK: - Screens

    private static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    private static func screen(withID displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { Self.displayID(of: $0) == displayID }
    }

    private func rebuildHoverAreas() {
        hoverAreas = NSScreen.screens.compactMap { screen in
            guard let displayID = Self.displayID(of: screen) else { return nil }
            return HoverArea(displayID: displayID, screen: screen)
        }
        logger.info("Hover areas rebuilt for \(self.hoverAreas.count) screen(s)")
    }

    private func screensChanged() {
        rebuildHoverAreas()
        perform(state.screensChanged(hoverAreas: hoverAreas, mode: panel.mode))
    }

    private func hoverArea(on displayID: CGDirectDisplayID) -> HoverArea? {
        hoverAreas.first { $0.displayID == displayID }
    }

    // MARK: - Hover

    private func mouseMoved() {
        updateClickThrough(at: NSEvent.mouseLocation)
        perform(state.mouseMoved(surroundings))
    }

    private var surroundings: NotchSurroundings {
        NotchSurroundings(
            cursor: NSEvent.mouseLocation,
            hoverAreas: hoverAreas,
            visibleShape: visibleRect,
            mode: panel.mode,
            isMenuTracking: isMenuTracking
        )
    }

    /// Carries out what a transition of `state` asks for.
    private func perform(_ effects: [NotchEffect]) {
        for effect in effects {
            switch effect {
            case .startHoverDelay(let displayID):
                startHoverDelay(on: displayID)
            case .cancelHoverDelay:
                cancelHoverDelay()
            case .open(let displayID):
                open(on: displayID)
            case .close:
                // The content fades out, the shape collapses into the hover area, then the window is ordered out.
                setMode(.closed)
                startCloseAnimation()
            case .reopen:
                closeAnimation.cancel()
                appModel.refreshSaveCard()
                setMode(.open)
            case .orderOut:
                window?.orderOut(nil)
            case .place(let displayID):
                if let window, let screen = Self.screen(withID: displayID), let area = hoverArea(on: displayID) {
                    place(window, on: screen, area: area)
                }
            case .closeAtOnce:
                setMode(.closed)
                orderOutNow()
            }
        }
    }

    private func startHoverDelay(on displayID: CGDirectDisplayID) {
        // Read on every hover, so a change in Settings (#9) applies without a restart.
        hoverDelay.schedule(after: Preferences.hoverDelay()) { [weak self] in
            guard let self else { return }
            self.perform(self.state.hoverDelayEnded(on: displayID))
        }
    }

    private func cancelHoverDelay() {
        hoverDelay.cancel()
    }

    // MARK: - Showing and hiding

    /// The visible shape: `appModel.shapeSize` hanging from the top center of the window.
    private var visibleRect: NSRect {
        guard let window else { return .zero }
        let size = appModel.shapeSize
        let frame = window.frame
        return NSRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height, width: size.width, height: size.height)
    }

    /// The window is much bigger than the visible shape, so it takes mouse events only while the
    /// cursor is over the shape; elsewhere clicks reach the windows below. Called on every mouse
    /// move (the global monitor sees moves over the window while it ignores events) and on open.
    private func updateClickThrough(at location: NSPoint) {
        guard let window, state.windowDisplayID != nil else { return }
        let ignores = !NotchState.isPoint(location, in: visibleRect)
        if window.ignoresMouseEvents != ignores {
            window.ignoresMouseEvents = ignores
        }
    }

    /// Top edge on the screen's top edge, centered on the hover area. The size never changes.
    private func place(_ window: NotchPanel, on screen: NSScreen, area: HoverArea) {
        let size = PanelLayout.windowSize
        let origin = NSPoint(x: area.rect.midX - size.width / 2, y: screen.frame.maxY - size.height)
        window.setFrame(NSRect(origin: origin, size: size), display: false)
        // The shape grows out of, and collapses back into, the notch (#11). Without a notch it
        // collapses into the top edge: the hover strip is invisible, so no pill is drawn (story 6).
        panel.closedSize = area.isNotch ? area.rect.size : CGSize(width: area.rect.width, height: 0)
    }

    /// Opens as `.open`, or as `.feedback` for the shortcut, which keeps the card the shortcut set.
    private func open(on displayID: CGDirectDisplayID, as mode: PanelModel.Mode = .open) {
        guard let window,
              let screen = Self.screen(withID: displayID),
              let area = hoverArea(on: displayID)
        else {
            // Nothing to show on: make sure no window is left fading or ordered in.
            state = .idle
            orderOutNow()
            return
        }
        closeAnimation.cancel()

        place(window, on: screen, area: area)
        state = .shown(displayID)

        // Re-evaluated on every open, because the clipboard may have changed while closed.
        if mode == .open {
            appModel.refreshSaveCard()
        }
        setMode(mode)
        updateClickThrough(at: NSEvent.mouseLocation)
        // Never makeKey or activate: the frontmost app keeps keyboard focus. Only search mode makes it key.
        window.orderFrontRegardless()
    }

    /// Reports `closeAnimationEnded()` once the close animation has run. `panel.mode` is already `.closed`.
    private func startCloseAnimation() {
        closeAnimation.schedule(after: Motion.closeDuration) { [weak self] in
            guard let self else { return }
            self.perform(self.state.closeAnimationEnded())
        }
    }

    /// Orders the window out at once, ending a running close.
    private func orderOutNow() {
        closeAnimation.cancel()
        window?.orderOut(nil)
    }

    // MARK: - Mode

    /// The one place the controller changes `panel.mode`, together with what the window does on
    /// leaving and entering a mode. Setting `panel.mode` itself only updates the panel's UI state.
    private func setMode(_ new: PanelModel.Mode) {
        let old = panel.mode
        guard new != old else { return }
        panel.mode = new
        if old == .feedback {
            feedback.cancel()
        }
        if new == .search {
            beginSearch()
        } else if old == .search {
            endSearch(closing: new == .closed)
        }
    }

    // MARK: - Search

    /// Makes the panel key so the search field gets typing. The panel is `.nonactivatingPanel`, so
    /// Topstash isn't activated and the frontmost app stays frontmost.
    private func beginSearch() {
        guard let window else { return }
        window.makeKey()

        // Global monitors see only events sent to other apps, so any click they report is outside the panel.
        searchMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.closeSearch() }
        }
        searchResignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.closeSearch() }
        }
    }

    /// Esc, a click outside, or the panel resigning key.
    func closeSearch() {
        guard panel.mode == .search else { return }
        // Esc or a click outside means "close": the cursor still over the panel doesn't reopen it.
        perform(state.dismiss())
    }

    private func endSearch(closing: Bool) {
        if let searchMouseMonitor {
            NSEvent.removeMonitor(searchMouseMonitor)
        }
        searchMouseMonitor = nil
        if let searchResignObserver {
            NotificationCenter.default.removeObserver(searchResignObserver)
        }
        searchResignObserver = nil

        guard closing else { return }
        // The next keystroke must go to the frontmost app's window, not the closing panel, while the
        // content and shape animate out like any close (#11). Ordering a key window out hands key
        // status back to the frontmost app, but ordering the panel itself out and back in blanks it
        // for a moment. So an invisible window takes key status from the panel and is ordered out.
        // Without a window (the controller was never started) there is no key status to hand back.
        if window != nil {
            keyHandback.handBackKey()
        }
    }

    // MARK: - Context menu (#6)

    /// Observes every menu of the app: a note row's context menu, and the menu bar extra's.
    private func observeMenuTracking() {
        let center = NotificationCenter.default
        menuObservers = [
            center.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.isMenuTracking = true }
            },
            center.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.isMenuTracking = false
                    // Close if the cursor ended up outside the panel.
                    self.mouseMoved()
                }
            },
        ]
    }

    /// Closes after an action (Open in Editor). The cursor still over the fading panel doesn't bring it back.
    func dismissAfterAction() {
        guard panel.mode != .closed else { return }
        perform(state.dismiss())
    }

    // MARK: - Global shortcut (#10)

    /// Saves the clipboard like a click on the card. A closed panel drops down briefly on the
    /// screen with the cursor to show the result; an open one updates its card in place.
    /// Never makes the panel key or activates the app, so typing continues in the frontmost app.
    func saveFromShortcut() {
        let result = appModel.saveClipboard()
        switch panel.mode {
        case .open:
            appModel.showSaveResult(result)
        case .search:
            appModel.showSaveResultInSearch(result)
        case .feedback:
            appModel.showSaveResult(result, reverts: false)
            startFeedbackTimer()
        case .closed:
            guard let displayID = displayIDUnderCursor() else {
                logger.error("No screen to show the shortcut's feedback on")
                return
            }
            // A hover delay running from before would replace the feedback with the normal panel.
            cancelHoverDelay()
            guard case .saved(let note) = result else {
                appModel.showSaveResult(result, reverts: false)
                open(on: displayID, as: .feedback)
                startFeedbackTimer()
                return
            }
            // A new save opens with the card showing the text, and plays the save feedback (fly-up,
            // gulp, checkmark, haptic) once the shape has expanded, so the gulp doesn't overlap the
            // expand spring (#11). The countdown starts with the feedback.
            appModel.showCardBeforeSave(of: note.body)
            open(on: displayID, as: .feedback)
            let settle = Motion.expandSettleDuration(
                reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            )
            // Leaving `.feedback`, or another press, cancels it like the countdown.
            feedback.schedule(after: settle) { [weak self] in
                guard let self else { return }
                self.appModel.showSaveResult(result, reverts: false)
                self.startFeedbackTimer()
            }
        }
    }

    /// The screen containing the cursor, else the main screen.
    private func displayIDUnderCursor() -> CGDirectDisplayID? {
        let location = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NotchState.isPoint(location, in: $0.frame) } ?? NSScreen.main
        return screen.flatMap(Self.displayID(of:))
    }

    /// Restarts the countdown, so another press shows its own result for the full duration.
    private func startFeedbackTimer() {
        feedback.schedule(after: Motion.feedbackDuration) { [weak self] in
            self?.feedbackEnded()
        }
    }

    /// Hides the panel, or switches to `.open` if the cursor is over it or its hover area. From
    /// then on the normal hover rules apply.
    private func feedbackEnded() {
        perform(state.feedbackEnded(surroundings))
    }
}

extension NotchPanelController: PanelActions {
    /// Expands the open panel into search mode (#5), which makes the panel key for the search field.
    func showAll() {
        setMode(.search)
    }
}
