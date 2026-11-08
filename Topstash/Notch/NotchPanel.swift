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
}

/// Lets the first click on a card register even though the panel isn't key.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
