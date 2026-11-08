import AppKit
import SwiftUI

/// A borderless panel above the menu bar that never activates the app or takes focus.
final class NotchPanel: NSPanel {
    init(rootView: some View) {
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

    // #5 makes this true while searching.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Lets the first click on a card register even though the panel never becomes key.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
