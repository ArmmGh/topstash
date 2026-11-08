import AppKit
import os

/// Tracks the mouse, applies the hover delay, and shows or hides the notch panel.
@MainActor
final class NotchPanelController {
    private let appModel: AppModel
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "io.github.armmgh.topstash", category: "NotchPanel")

    private var window: NotchPanel?
    private var screen: NSScreen?
    private var hoverRect: NSRect?

    private var monitors: [Any] = []
    private var hoverTask: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?

    private var panel: PanelModel { appModel.panel }

    init(appModel: AppModel, defaults: UserDefaults = .standard) {
        self.appModel = appModel
        self.defaults = defaults
    }

    func start() {
        window = NotchPanel(rootView: PanelView(appModel: appModel))

        // This ticket uses the first screen with a notch. #8 adds other screens.
        for candidate in NSScreen.screens {
            if let rect = HoverArea.rect(for: candidate) {
                screen = candidate
                hoverRect = rect
                break
            }
        }
        if hoverRect == nil {
            logger.info("No notched screen found; the panel can't be opened yet")
        }

        // Mouse-moved monitors don't need Accessibility permission. The local monitor covers the
        // cursor being over our own panel, where global events aren't delivered.
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
    }

    // MARK: - Hover

    private func mouseMoved() {
        guard let hoverRect else { return }
        let location = NSEvent.mouseLocation
        let inHoverArea = hoverRect.contains(location)

        switch panel.mode {
        case .open:
            if inHoverArea || visibleRect.contains(location) {
                return
            }
            close()
        case .closed:
            if closeTask != nil, inHoverArea || visibleRect.contains(location) {
                // The cursor came back during the fade.
                closeTask?.cancel()
                closeTask = nil
                panel.mode = .open
            } else if inHoverArea {
                startHoverDelay()
            } else {
                hoverTask?.cancel()
                hoverTask = nil
            }
        }
    }

    private func startHoverDelay() {
        guard hoverTask == nil else { return }
        // Read on every hover, so a change in Settings (#9) applies without a restart.
        let delay = Preferences.hoverDelay(defaults)
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            self.hoverTask = nil
            self.open()
        }
    }

    // MARK: - Showing and hiding

    /// The visible shape: `contentSize` hanging from the top center of the window.
    private var visibleRect: NSRect {
        guard let window else { return .zero }
        let size = panel.contentSize
        let frame = window.frame
        return NSRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height, width: size.width, height: size.height)
    }

    private func open() {
        guard let window, let screen else { return }
        closeTask?.cancel()
        closeTask = nil

        let size = PanelLayout.windowSize
        let origin = NSPoint(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height)
        window.setFrame(NSRect(origin: origin, size: size), display: false)

        panel.mode = .open
        // Never makeKey or activate: the frontmost app keeps keyboard focus.
        window.orderFrontRegardless()
    }

    private func close() {
        panel.mode = .closed
        closeTask?.cancel()
        closeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(PanelLayout.fadeDuration))
            guard !Task.isCancelled, let self else { return }
            self.closeTask = nil
            self.window?.orderOut(nil)
        }
    }
}
