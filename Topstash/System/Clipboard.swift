import AppKit

/// A thin wrapper around `NSPasteboard`.
@MainActor
struct Clipboard {
    var pasteboard: NSPasteboard = .general

    /// The `.string` type only.
    func readText() -> String? {
        pasteboard.string(forType: .string)
    }
}
