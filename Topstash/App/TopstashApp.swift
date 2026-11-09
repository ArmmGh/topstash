import SwiftUI

@main
struct TopstashApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Topstash", systemImage: "tray.and.arrow.down") {
            MenuBarMenu(appModel: appDelegate.appModel)
        }
        Settings {
            SettingsView(appModel: appDelegate.appModel)
        }
    }
}

/// The menu bar icon's menu.
private struct MenuBarMenu: View {
    let appModel: AppModel

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Settings…") {
            openSettings()
            // An agent app's Settings window otherwise opens behind the frontmost app.
            NSApp.activate()
        }
        .keyboardShortcut(",")
        Button("Open Notes Folder") {
            NSWorkspace.shared.open(appModel.store.folder)
        }
        Divider()
        Button("Quit Topstash") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
