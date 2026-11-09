import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Saves the clipboard from any app. ⌥⌘S by default; KeyboardShortcuts stores a change
    /// from Settings in `UserDefaults`. While Topstash runs, it takes over "Save All" in Xcode and
    /// VS Code, which is why it can be changed.
    static let saveClipboard = Self("saveClipboard", default: .init(.s, modifiers: [.option, .command]))
}
