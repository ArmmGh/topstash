@testable import Topstash

/// Stands in for the system clipboard. Counts reads of its contents, so a test can prove the
/// paste privacy alert would never have shown.
@MainActor
final class FakeClipboard: Clipboard {
    /// The clipboard's text. `nil` means it holds no text.
    var text: String?
    var access: PasteAccess
    var marker: ClipboardMarker?
    private(set) var changeCount = 0
    /// How many times the contents were read.
    private(set) var readCount = 0

    init(text: String? = nil, access: PasteAccess = .allowed, marker: ClipboardMarker? = nil) {
        self.text = text
        self.access = access
        self.marker = marker
    }

    func hasText() -> Bool {
        text != nil
    }

    /// Like the system clipboard, returns nothing when access is denied.
    func readText() -> String? {
        readCount += 1
        return access == .denied ? nil : text
    }

    func write(_ text: String) {
        self.text = text
        // The app's own copy is plain text, like `SystemClipboard.write`.
        marker = nil
        changeCount += 1
    }

    /// Another app replacing the clipboard's contents, with `marker` if it marked them.
    func simulateCopy(_ text: String?, marker: ClipboardMarker? = nil) {
        self.text = text
        self.marker = marker
        changeCount += 1
    }
}
