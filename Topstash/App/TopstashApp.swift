import SwiftUI

@main
struct TopstashApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The Settings scene comes in #9.
        MenuBarExtra("Topstash", systemImage: "tray.and.arrow.down") {
            Button("Quit Topstash") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
