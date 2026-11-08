import AppKit
import os

/// Tracks the mouse, applies the hover delay, and shows or hides the notch panel on the hovered screen.
@MainActor
final class NotchPanelController {
    /// One hover area per connected screen.
    private struct HoverTarget {
        let displayID: CGDirectDisplayID
        let rect: NSRect
    }

    private let appModel: AppModel
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "io.github.armmgh.topstash", category: "NotchPanel")

    private var window: NotchPanel?
    private var targets: [HoverTarget] = []
    /// The screen the panel is shown on, while the window is ordered in.
    private var openDisplayID: CGDirectDisplayID?

    private var monitors: [Any] = []
    private var screenObserver: (any NSObjectProtocol)?
    private var hoverTask: Task<Void, Never>?
    /// The target the pending hover delay belongs to.
    private var hoverDisplayID: CGDirectDisplayID?
    private var closeTask: Task<Void, Never>?
    /// Installed only while in search mode: closes the panel on a click outside or when it resigns key.
    private var searchMouseMonitor: Any?
    private var searchResignObserver: (any NSObjectProtocol)?

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
        rebuildTargets()

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
    }

    // MARK: - Screens

    private static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    private static func screen(withID displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { Self.displayID(of: $0) == displayID }
    }

    private func rebuildTargets() {
        targets = NSScreen.screens.compactMap { screen in
            guard let displayID = Self.displayID(of: screen) else { return nil }
            return HoverTarget(displayID: displayID, rect: HoverArea.rect(for: screen))
        }
        logger.info("Hover areas rebuilt for \(self.targets.count) screen(s)")
    }

    private func screensChanged() {
        rebuildTargets()
        cancelHoverDelay()

        guard let window, let openDisplayID else { return }
        if let screen = Self.screen(withID: openDisplayID), let target = target(withID: openDisplayID) {
            place(window, on: screen, centeredOn: target.rect)
        } else {
            // The panel's screen is gone: close right away, without the fade.
            closeTask?.cancel()
            closeTask = nil
            panel.mode = .closed
            window.orderOut(nil)
            self.openDisplayID = nil
        }
    }

    private func target(withID displayID: CGDirectDisplayID) -> HoverTarget? {
        targets.first { $0.displayID == displayID }
    }

    // MARK: - Hover

    private func mouseMoved() {
        let location = NSEvent.mouseLocation
        let hovered = targets.first { $0.rect.contains(location) }
        // Over the hover area or the visible shape of the screen the panel is shown on.
        let overOpenPanel = openDisplayID != nil
            && (hovered?.displayID == openDisplayID || visibleRect.contains(location))

        switch panel.mode {
        case .open:
            if !overOpenPanel {
                close()
            }
        case .search:
            // Stays open when the cursor leaves; see `beginSearch()` for what closes it.
            break
        case .closed:
            if closeTask != nil, overOpenPanel {
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

    private func startHoverDelay(for target: HoverTarget) {
        // Keep a running delay for the same target; restart it when the cursor moves to another one.
        if hoverTask != nil, hoverDisplayID == target.displayID { return }
        cancelHoverDelay()

        // Read on every hover, so a change in Settings (#9) applies without a restart.
        let delay = Preferences.hoverDelay(defaults)
        let displayID = target.displayID
        hoverDisplayID = displayID
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
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

    /// Top edge on the screen's top edge, centered on the hover area. The size never changes.
    private func place(_ window: NotchPanel, on screen: NSScreen, centeredOn hoverRect: NSRect) {
        let size = PanelLayout.windowSize
        let origin = NSPoint(x: hoverRect.midX - size.width / 2, y: screen.frame.maxY - size.height)
        window.setFrame(NSRect(origin: origin, size: size), display: false)
    }

    private func open(on displayID: CGDirectDisplayID) {
        guard let window,
              let screen = Self.screen(withID: displayID),
              let target = target(withID: displayID)
        else { return }
        closeTask?.cancel()
        closeTask = nil

        place(window, on: screen, centeredOn: target.rect)
        openDisplayID = displayID

        // Re-evaluated on every open, because the clipboard may have changed while closed.
        appModel.refreshSaveCard()
        panel.mode = .open
        // Never makeKey or activate: the frontmost app keeps keyboard focus. Only search mode makes it key.
        window.orderFrontRegardless()
    }

    private func close() {
        panel.mode = .closed
        closeTask?.cancel()
        closeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(PanelLayout.fadeDuration))
            guard !Task.isCancelled, let self else { return }
            self.closeTask = nil
            self.openDisplayID = nil
            self.window?.orderOut(nil)
        }
    }

    // MARK: - Search

    private func modeChanged(from old: PanelModel.Mode, to new: PanelModel.Mode) {
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
        // Ordered out right away, without the fade, so the next keystroke goes back to the
        // frontmost app's window instead of the fading panel.
        closeTask?.cancel()
        closeTask = nil
        openDisplayID = nil
        window?.orderOut(nil)
    }
}
