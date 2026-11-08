import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Created with the delegate, so the app's scenes (menu bar, Settings) can use it from the start.
    let appModel = AppModel()
    private var panelController: NotchPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panelController = NotchPanelController(appModel: appModel)
        panelController.start()
        self.panelController = panelController
    }
}
