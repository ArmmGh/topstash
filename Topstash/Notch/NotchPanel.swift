import AppKit
import SwiftUI

/// A borderless panel above the menu bar that never activates the app. It takes keyboard focus
/// only while `allowsKey` says so (the search field), and even then the frontmost app stays frontmost.
final class NotchPanel: NSPanel {
    private let allowsKey: () -> Bool

    init(rootView: some View, allowsKey: @escaping () -> Bool) {
        self.allowsKey = allowsKey
        super.init(
            contentRect: NSRect(origin: .zero, size: PanelLayout.windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
        contentView = FirstMouseHostingView(rootView: rootView)
    }

    override var canBecomeKey: Bool { allowsKey() }
    override var canBecomeMain: Bool { false }

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

/// Lets the first click on a card register even though the panel isn't key.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
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
        isOpaque = false
        backgroundColor = .clear
        alphaValue = 0
        hasShadow = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces, .stationary, .ignoresCycle]
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
