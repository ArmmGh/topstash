import AppKit

/// Whether reading the clipboard's contents would show macOS's paste privacy alert.
enum PasteAccess: Equatable {
    case allowed
    case wouldPrompt
    case denied
}

/// The clipboard as the app sees it: `SystemClipboard` in the app, a fake in tests.
@MainActor
protocol Clipboard {
    /// The user's Paste setting for this app.
    var access: PasteAccess { get }
    /// Changes whenever any app replaces the clipboard's contents. Reading it never shows the alert.
    var changeCount: Int { get }
    /// Whether the clipboard holds text. Never shows the paste privacy alert.
    func hasText() -> Bool
    /// The clipboard's text. May show the paste privacy alert, so call it only on a click,
    /// the shortcut, or when `access == .allowed`.
    func readText() -> String?
    /// Replaces the clipboard contents with `text`.
    func write(_ text: String)
}

/// A thin wrapper around `NSPasteboard`.
@MainActor
struct SystemClipboard: Clipboard {
    private let pasteboard: NSPasteboard = .general

    /// The Paste privacy pane in System Settings.
    static let pastePrivacySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Pasteboard"
    )!

    /// From the user's Paste setting for this app (macOS 15.4+). Earlier systems never prompt.
    var access: PasteAccess {
        guard #available(macOS 15.4, *) else { return .allowed }
        switch pasteboard.accessBehavior {
        case .alwaysAllow:
            return .allowed
        case .alwaysDeny:
            return .denied
        case .ask:
            return .wouldPrompt
        case .default:
            // On macOS 15.x the alert is an opt-in developer preview, so the untouched setting
            // never alerts. Placeholder for macOS 26+ until the manual check in #4 shows whether it does.
            if #available(macOS 26, *) { return .wouldPrompt }
            return .allowed
        @unknown default:
            return .wouldPrompt
        }
    }

    /// Changes whenever any app replaces the clipboard's contents. Reading it never shows the alert.
    var changeCount: Int {
        pasteboard.changeCount
    }

    /// Whether the clipboard holds `.string` text. Inspects the types, not the contents,
    /// so it never shows the paste privacy alert.
    func hasText() -> Bool {
        pasteboard.availableType(from: [.string]) != nil
    }

    /// The `.string` type only. May show the paste privacy alert, so call it only on a click,
    /// the shortcut, or when `access == .allowed`.
    func readText() -> String? {
        pasteboard.string(forType: .string)
    }

    /// Replaces the clipboard contents with `text` as `.string`.
    func write(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
