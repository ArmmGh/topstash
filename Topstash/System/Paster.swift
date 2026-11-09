import Carbon.HIToolbox
import CoreGraphics

/// Pastes into the frontmost app by posting ⌘V, for ⌥Return in search. A protocol so tests can
/// stand in for the system, which needs Accessibility permission to post key events.
@MainActor
protocol Paster {
    /// Whether Topstash may post key events. When it may not, asks: macOS shows its Accessibility
    /// prompt the first time and only returns `false` after that.
    func requestAccess() -> Bool
    /// Posts ⌘V to the frontmost app. Does nothing without access.
    func paste()
}

struct SystemPaster: Paster {
    func requestAccess() -> Bool {
        CGPreflightPostEventAccess() || CGRequestPostEventAccess()
    }

    func paste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        // The user is still holding ⌥ from ⌥Return. Setting the flags makes the paste ⌘V, not ⌥⌘V.
        let keyCode = CGKeyCode(kVK_ANSI_V)
        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown)
            event?.flags = .maskCommand
            event?.post(tap: .cgSessionEventTap)
        }
    }
}
