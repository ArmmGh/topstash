import AppKit
import KeyboardShortcuts

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Created with the delegate, so the app's scenes (menu bar, Settings) can use it from the start.
    let appModel = AppModel()
    private var panelController: NotchPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panelController = NotchPanelController(appModel: appModel)
        panelController.start()
        self.panelController = panelController

        // A Carbon hot key: works while any app is frontmost, without Accessibility permission.
        // The handler runs on the main thread.
        KeyboardShortcuts.onKeyUp(for: .saveClipboard) { [weak panelController] in
            panelController?.saveFromShortcut()
        }
    }
}
