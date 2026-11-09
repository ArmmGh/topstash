import KeyboardShortcuts
import SwiftUI

@main
struct TopstashApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Topstash", systemImage: PanelStyle.saveSymbol) {
            MenuBarMenu(appModel: appDelegate.appModel) { [weak appDelegate] in
                appDelegate?.panelController?.openSearchFromMenu()
            }
        }
        Settings {
            SettingsView(appModel: appDelegate.appModel)
        }
    }
}

/// The menu bar icon's menu.
private struct MenuBarMenu: View {
    let appModel: AppModel
    let searchNotes: () -> Void

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        // Shows the search shortcut once one is set, and follows changes made in Settings.
        // It's registered as a global hot key, so the button doesn't need to handle it.
        Button("Search Notes…", action: searchNotes)
            .globalKeyboardShortcut(.searchNotes)
        Divider()
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
