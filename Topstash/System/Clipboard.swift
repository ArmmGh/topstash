import AppKit

/// A thin wrapper around `NSPasteboard`.
@MainActor
struct Clipboard {
    var pasteboard: NSPasteboard = .general

    /// The `.string` type only.
    func readText() -> String? {
        pasteboard.string(forType: .string)
    }

    /// Replaces the clipboard contents with `text` as `.string`.
    func write(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
