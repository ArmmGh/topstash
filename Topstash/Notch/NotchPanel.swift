import AppKit
import SwiftUI

/// A borderless panel above the menu bar that never activates the app. It takes keyboard focus
/// only while `allowsKey` says so (the search field), and even then the frontmost app stays frontmost.
final class NotchPanel: NSPanel {
    private let allowsKey: () -> Bool
    /// The primary or secondary button went down anywhere in the panel, before any view sees it.
    var onPressBegan: () -> Void = {}
    /// The primary or secondary button came up in the panel, after the view under it has handled
    /// the click.
    var onPressEnded: () -> Void = {}
    /// A force click or a three-finger tap, wherever the cursor is in the panel. `buttonIsDown` is
    /// false for the tap, which no mouse-up follows. The Look up hook and pressure stage 2 may both
    /// report one force click.
    var onForceClick: (_ buttonIsDown: Bool) -> Void = { _ in }

    init(rootView: some View, allowsKey: @escaping () -> Bool) {
        self.allowsKey = allowsKey
        super.init(
            contentRect: NSRect(origin: .zero, size: PanelLayout.windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        configureAsOverlay()
        isFloatingPanel = true
        level = .statusBar
        acceptsMouseMovedEvents = true
        let hostingView = FirstMouseHostingView(rootView: rootView)
        hostingView.onForceClick = { [weak self] buttonIsDown in self?.onForceClick(buttonIsDown) }
        contentView = hostingView
    }

    override var canBecomeKey: Bool { allowsKey() }
    override var canBecomeMain: Bool { false }

    /// Every press in the panel, reported here before and after the views see it, so a force
    /// click's state never outlives its press, whatever the gesture recognizer saw of it.
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .rightMouseDown:
            onPressBegan()
            super.sendEvent(event)
        case .leftMouseUp, .rightMouseUp:
            super.sendEvent(event)
            // On the next turn, in case the row's button acts on its mouse-up asynchronously.
            DispatchQueue.main.async { [weak self] in self?.onPressEnded() }
        default:
            super.sendEvent(event)
        }
    }

    /// An agent app has no Edit menu, so nothing turns ⌘V, ⌘C, ⌘X, ⌘A, ⌘Z, and ⇧⌘Z into actions.
    /// Sends them to the first responder (the search field's editor) instead.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if super.performKeyEquivalent(with: event) { return true }
        guard let action = Self.editAction(for: event) else { return false }
        return NSApp.sendAction(action, to: nil, from: self)
    }

    private static func editAction(for event: NSEvent) -> Selector? {
        // Only the modifiers a shortcut is made of: Caps Lock, Fn, and the numeric-pad flag are ignored.
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        switch (modifiers, event.charactersIgnoringModifiers?.lowercased()) {
        case ([.command], "v"): return #selector(NSText.paste(_:))
        case ([.command], "c"): return #selector(NSText.copy(_:))
        case ([.command], "x"): return #selector(NSText.cut(_:))
        case ([.command], "a"): return #selector(NSResponder.selectAll(_:))
        case ([.command], "z"): return Selector(("undo:"))
        case ([.command, .shift], "z"): return Selector(("redo:"))
        default: return nil
        }
    }
}

/// Lets the first click on a card register even though the panel isn't key, and watches the whole
/// panel for force clicks, so the rows stay SwiftUI buttons.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    var onForceClick: (_ buttonIsDown: Bool) -> Void = { _ in }

    required init(rootView: Content) {
        super.init(rootView: rootView)
        // The default already, set to say what the panel expects: a force click, with its haptic.
        pressureConfiguration = NSPressureConfiguration(pressureBehavior: .primaryDeepClick)
        let recognizer = ForceClickRecognizer()
        recognizer.onStageTwo = { [weak self] in self?.onForceClick(true) }
        addGestureRecognizer(recognizer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// The primary button's bit in `NSEvent.pressedMouseButtons`.
    private static var primaryButtonMask: Int { 1 << 0 }

    /// The system's Look up gesture: a force click or a three-finger tap, as the user's trackpad
    /// setting says. Overridden here because it skips from the window straight to NSApp.
    override func quickLook(with event: NSEvent) {
        onForceClick(NSEvent.pressedMouseButtons & Self.primaryButtonMask != 0)
    }
}

/// Reports pressure reaching stage 2 (a force click). Never recognizes, so the SwiftUI button under
/// it still gets the click, its press dip, and its context menu. `NotchPanel` reports the presses.
private final class ForceClickRecognizer: NSGestureRecognizer {
    var onStageTwo: () -> Void = {}

    override init(target: Any? = nil, action: Selector? = nil) {
        super.init(target: target, action: action)
        delaysPrimaryMouseButtonEvents = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func pressureChange(with event: NSEvent) {
        // `PanelModel.forceClick` counts one per press, so the repeats while held don't matter.
        if event.stage >= 2 { onStageTwo() }
    }
}

/// An invisible, never-visible-to-the-user panel whose only job is to take key status from the
/// notch panel and give it straight back to the frontmost app (see `handBackKey()`).
final class KeyHandbackPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        // The same Spaces and full-screen behavior as the notch panel, so it can take key status on any of them.
        configureAsOverlay()
        alphaValue = 0
        ignoresMouseEvents = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Becomes key, then orders out: like any key panel of a non-active app that is ordered out,
    /// key status returns to the frontmost app's window.
    func handBackKey() {
        makeKeyAndOrderFront(nil)
        orderOut(nil)
    }
}

extension NSPanel {
    /// Transparent, shadowless, kept when the app deactivates or the panel closes, and shown on
    /// every Space and over full-screen apps.
    fileprivate func configureAsOverlay() {
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        // No system fade on ordering in and out: it showed a translucent ghost of the closed shape
        // beside the notch. The SwiftUI content does all the animating.
        animationBehavior = .none
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces, .stationary, .ignoresCycle]
    }
}
