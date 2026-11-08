import AppKit

/// Whether reading the clipboard's contents would show macOS's paste privacy alert.
enum PasteAccess: Equatable {
    case allowed
    case wouldPrompt
    case denied
}

/// A thin wrapper around `NSPasteboard`.
@MainActor
struct Clipboard {
    var pasteboard: NSPasteboard = .general

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
            // Placeholder until the manual check in #4 shows whether `.default` alerts on macOS 26.
            return .wouldPrompt
        @unknown default:
            return .wouldPrompt
        }
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
