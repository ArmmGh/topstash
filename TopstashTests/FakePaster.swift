@testable import Topstash

/// Stands in for posting ⌘V. Counts access requests, so a test can prove the Accessibility prompt
/// would never have shown, and records the panel's mode at each paste.
@MainActor
final class FakePaster: Paster {
    /// What `requestAccess()` answers: the user's choice in System Settings.
    var isAllowed: Bool
    private(set) var accessRequestCount = 0
    /// Called on each paste, so a test can check what the panel was doing at that moment.
    var onPaste: () -> Void = {}
    private(set) var pasteCount = 0

    init(isAllowed: Bool = true) {
        self.isAllowed = isAllowed
    }

    func requestAccess() -> Bool {
        accessRequestCount += 1
        return isAllowed
    }

    func paste() {
        pasteCount += 1
        onPaste()
    }
}
