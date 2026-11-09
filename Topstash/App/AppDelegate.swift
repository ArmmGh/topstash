import AppKit
import KeyboardShortcuts

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Created with the delegate, so the app's scenes (menu bar, Settings) can use it from the start.
    let appModel = AppModel()
    private var panelController: NotchPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The unit tests run inside the app. There, the notch panel and the global shortcut
        // would only get in the way of a copy of Topstash the user may have running.
        guard !Self.isHostingTests else { return }

        let panelController = NotchPanelController(appModel: appModel)
        panelController.start()
        self.panelController = panelController

        // A Carbon hot key: works while any app is frontmost, without Accessibility permission.
        // The handler runs on the main thread.
        KeyboardShortcuts.onKeyUp(for: .saveClipboard) { [weak panelController] in
            panelController?.saveFromShortcut()
        }
        KeyboardShortcuts.onKeyUp(for: .searchNotes) { [weak panelController] in
            panelController?.toggleSearch()
        }
    }

    /// "Search Notes…" in the menu bar.
    func openSearch() {
        panelController?.openSearchOnCursorScreen()
    }

    /// Set by Xcode when it launches the app to host the test bundle.
    private static let isHostingTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}
