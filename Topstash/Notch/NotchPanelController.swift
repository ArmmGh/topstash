import AppKit
import os
import TopstashCore

/// Tracks the mouse, applies the hover delay, and shows or hides the notch panel on the hovered screen.
@MainActor
final class NotchPanelController {
    private let appModel: AppModel
    private let defaults: UserDefaults
    private let logger = Logger(category: "NotchPanel")

    private var window: NotchPanel?
    /// Hands key status back to the frontmost app when search closes, without ordering `window` out.
    private let keyHandback = KeyHandbackPanel()
    /// One per connected screen.
    private var hoverAreas: [HoverArea] = []
    /// The screen the panel is shown on, while the window is ordered in.
    private var openDisplayID: CGDirectDisplayID?

    private var monitors: [Any] = []
    private var screenObserver: (any NSObjectProtocol)?
    private var hoverTask: Task<Void, Never>?
    /// The screen whose hover area the pending hover delay belongs to.
    private var hoverDisplayID: CGDirectDisplayID?
    private var closeTask: Task<Void, Never>?
    /// Installed only while in search mode: closes the panel on a click outside or when it resigns key.
    private var searchMouseMonitor: Any?
    private var searchResignObserver: (any NSObjectProtocol)?
    private var menuObservers: [any NSObjectProtocol] = []
    /// True while any menu of the app is open.
    private var isMenuTracking = false
    /// Set by `dismiss()` until the panel opens again.
    private var isDismissed = false
    /// Ends the shortcut's feedback (#10).
    private var feedbackTask: Task<Void, Never>?

    private var panel: PanelModel { appModel.panel }

    init(appModel: AppModel, defaults: UserDefaults = .standard) {
        self.appModel = appModel
        self.defaults = defaults
    }

    func start() {
        window = NotchPanel(rootView: PanelView(appModel: appModel)) { [weak self] in
            self?.panel.mode == .search
        }
        panel.onModeChange = { [weak self] old, new in
            self?.modeChanged(from: old, to: new)
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
        appModel.closePanel = { [weak self] in self?.dismiss() }
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
            return HoverArea(displayID: displayID, rect: HoverArea.rect(for: screen))
        }
        logger.info("Hover areas rebuilt for \(self.hoverAreas.count) screen(s)")
    }

    private func screensChanged() {
        rebuildHoverAreas()
        cancelHoverDelay()

        guard let window, let openDisplayID else { return }
        if let screen = Self.screen(withID: openDisplayID), let area = hoverArea(on: openDisplayID) {
            place(window, on: screen, centeredOn: area.rect)
        } else {
            // The panel's screen is gone: close right away, without the fade.
            panel.mode = .closed
            orderOutNow()
        }
    }

    private func hoverArea(on displayID: CGDirectDisplayID) -> HoverArea? {
        hoverAreas.first { $0.displayID == displayID }
    }

    // MARK: - Hover

    private func mouseMoved() {
        let location = NSEvent.mouseLocation
        updateClickThrough(at: location)
        // The menu is its own window, so the cursor on it counts as outside the panel.
        guard !isMenuTracking else { return }
        let hovered = hoverAreas.first { $0.rect.contains(location) }
        let overOpenPanel = isOverOpenPanel(location)

        switch panel.mode {
        case .open:
            if !overOpenPanel {
                close()
            }
        case .search:
            // Stays open when the cursor leaves; see `beginSearch()` for what closes it.
            break
        case .feedback:
            // `feedbackEnded()` decides when the time is up.
            break
        case .closed:
            if closeTask != nil, !isDismissed, overOpenPanel {
                // The cursor came back during the fade.
                closeTask?.cancel()
                closeTask = nil
                appModel.refreshSaveCard()
                panel.mode = .open
            } else if let hovered {
                startHoverDelay(for: hovered)
            } else {
                cancelHoverDelay()
            }
        }
    }

    private func startHoverDelay(for area: HoverArea) {
        // Keep a running delay for the same screen; restart it when the cursor moves to another one.
        if hoverTask != nil, hoverDisplayID == area.displayID { return }
        cancelHoverDelay()

        // Read on every hover, so a change in Settings (#9) applies without a restart.
        let delay = Preferences.hoverDelay(defaults)
        let displayID = area.displayID
        hoverDisplayID = displayID
        hoverTask = .afterDelay(delay) { [weak self] in
            guard let self else { return }
            self.hoverTask = nil
            self.hoverDisplayID = nil
            self.open(on: displayID)
        }
    }

    private func cancelHoverDelay() {
        hoverTask?.cancel()
        hoverTask = nil
        hoverDisplayID = nil
    }

    // MARK: - Showing and hiding

    /// The visible shape: `contentSize` hanging from the top center of the window.
    private var visibleRect: NSRect {
        guard let window else { return .zero }
        let size = panel.contentSize
        let frame = window.frame
        return NSRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height, width: size.width, height: size.height)
    }

    /// The window is much bigger than the visible shape, so it takes mouse events only while the
    /// cursor is over the shape; elsewhere clicks reach the windows below. Called on every mouse
    /// move (the global monitor sees moves over the window while it ignores events) and on open.
    private func updateClickThrough(at location: NSPoint) {
        guard let window, openDisplayID != nil else { return }
        let ignores = !visibleRect.contains(location)
        if window.ignoresMouseEvents != ignores {
            window.ignoresMouseEvents = ignores
        }
    }

    /// Top edge on the screen's top edge, centered on the hover area. The size never changes.
    private func place(_ window: NotchPanel, on screen: NSScreen, centeredOn hoverRect: NSRect) {
        let size = PanelLayout.windowSize
        let origin = NSPoint(x: hoverRect.midX - size.width / 2, y: screen.frame.maxY - size.height)
        window.setFrame(NSRect(origin: origin, size: size), display: false)
        // The shape grows out of, and collapses back into, this screen's hover area (#11).
        panel.closedSize = hoverRect.size
    }

    /// Opens as `.open`, or as `.feedback` for the shortcut, which keeps the card the shortcut set.
    private func open(on displayID: CGDirectDisplayID, as mode: PanelModel.Mode = .open) {
        guard let window,
              let screen = Self.screen(withID: displayID),
              let area = hoverArea(on: displayID)
        else { return }
        closeTask?.cancel()
        closeTask = nil
        isDismissed = false

        place(window, on: screen, centeredOn: area.rect)
        openDisplayID = displayID

        // Re-evaluated on every open, because the clipboard may have changed while closed.
        if mode == .open {
            appModel.refreshSaveCard()
        }
        panel.mode = mode
        // `contentSize` follows the new mode after the next layout; until the cursor moves, the
        // shape counts as its closed size, which contains the cursor when it opened by hovering.
        updateClickThrough(at: NSEvent.mouseLocation)
        // Never makeKey or activate: the frontmost app keeps keyboard focus. Only search mode makes it key.
        window.orderFrontRegardless()
    }

    /// Whether `location` is over the hover area or the visible shape of the screen the panel is shown on.
    private func isOverOpenPanel(_ location: NSPoint) -> Bool {
        guard let openDisplayID else { return false }
        let overHoverArea = hoverArea(on: openDisplayID)?.rect.contains(location) ?? false
        return overHoverArea || visibleRect.contains(location)
    }

    /// The content fades out, the shape collapses into the hover area, then the window is ordered out.
    private func close() {
        panel.mode = .closed
        orderOutAfterClosing()
    }

    /// Orders the window out once the close animation has run. `panel.mode` is already `.closed`.
    private func orderOutAfterClosing() {
        closeTask?.cancel()
        closeTask = .afterDelay(Motion.closeDuration) { [weak self] in
            self?.orderOutNow()
        }
    }

    /// Orders the window out at once, ending a running close.
    private func orderOutNow() {
        closeTask?.cancel()
        closeTask = nil
        openDisplayID = nil
        window?.orderOut(nil)
    }

    // MARK: - Search

    private func modeChanged(from old: PanelModel.Mode, to new: PanelModel.Mode) {
        if old == .feedback {
            feedbackTask?.cancel()
            feedbackTask = nil
        }
        if new == .search {
            beginSearch()
        } else if old == .search {
            endSearch(closing: new == .closed)
        }
    }

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
    private func closeSearch() {
        guard panel.mode == .search else { return }
        panel.mode = .closed
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
        keyHandback.handBackKey()
        // Esc or a click outside means "close": the cursor still over the panel doesn't reopen it.
        isDismissed = true
        orderOutAfterClosing()
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
    private func dismiss() {
        guard panel.mode != .closed else { return }
        isDismissed = true
        close()
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
            guard case .success(.saved(let note)) = result else {
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
            feedbackTask = .afterDelay(settle) { [weak self] in
                guard let self else { return }
                self.appModel.showSaveResult(result, reverts: false)
                self.startFeedbackTimer()
            }
        }
    }

    /// The screen containing the cursor, else the main screen.
    private func displayIDUnderCursor() -> CGDirectDisplayID? {
        let location = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(location, $0.frame, false) } ?? NSScreen.main
        return screen.flatMap(Self.displayID(of:))
    }

    /// Restarts the countdown, so another press shows its own result for the full duration.
    private func startFeedbackTimer() {
        feedbackTask?.cancel()
        feedbackTask = .afterDelay(Motion.feedbackDuration) { [weak self] in
            guard let self else { return }
            self.feedbackTask = nil
            self.feedbackEnded()
        }
    }

    /// Hides the panel, or switches to `.open` if the cursor is over it or its hover area. From
    /// then on the normal hover rules apply.
    private func feedbackEnded() {
        guard panel.mode == .feedback else { return }
        if isOverOpenPanel(NSEvent.mouseLocation) {
            appModel.refreshSaveCard()
            panel.mode = .open
        } else {
            close()
        }
    }
}
