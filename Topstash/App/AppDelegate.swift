import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var appModel: AppModel?
    private var panelController: NotchPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let appModel = AppModel()
        let panelController = NotchPanelController(appModel: appModel)
        panelController.start()
        self.appModel = appModel
        self.panelController = panelController
    }
}
