import AppKit
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

/// The Settings window: notes folder, save shortcut, hover delay, and launch at login.
struct SettingsView: View {
    let appModel: AppModel

    @AppStorage(Preferences.hoverDelayMillisecondsKey)
    private var hoverDelayMilliseconds = Preferences.defaultHoverDelayMilliseconds
    @State private var launchAtLogin = LaunchAtLogin()
    @State private var folderError: String?
    @State private var launchAtLoginError: String?

    var body: some View {
        Form {
            folderSection
            shortcutSection
            hoverDelaySection
            launchAtLoginSection
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { launchAtLogin.refresh() }
        // The user may have changed Login Items in System Settings meanwhile.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            launchAtLogin.refresh()
        }
    }

    // MARK: - Notes folder

    private var folderSection: some View {
        Section {
            LabeledContent("Notes folder") {
                HStack {
                    Text(abbreviatedPath(appModel.store.folder))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .help(appModel.store.folder.path(percentEncoded: false))
                    Button("Choose…", action: chooseFolder)
                }
            }
            if let folderError {
                errorText(folderError)
            }
        }
    }

    private func abbreviatedPath(_ url: URL) -> String {
        (url.path(percentEncoded: false) as NSString).abbreviatingWithTildeInPath
    }

    private func chooseFolder() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.canCreateDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Choose"
        openPanel.directoryURL = appModel.store.folder
        guard openPanel.runModal() == .OK, let url = openPanel.url else { return }
        do {
            try appModel.setFolder(url)
            folderError = nil
        } catch {
            folderError = "Couldn't use this folder: \(error.localizedDescription)"
        }
    }

    // MARK: - Shortcut (#10)

    private var shortcutSection: some View {
        Section {
            // KeyboardShortcuts stores the shortcut in UserDefaults and re-registers it right away.
            KeyboardShortcuts.Recorder("Save clipboard", name: .saveClipboard)
        }
    }

    // MARK: - Hover delay

    private var hoverDelaySection: some View {
        Section {
            // The controller reads the delay on every hover, so a change applies on the next one.
            LabeledContent("Hover delay") {
                HStack {
                    Slider(value: hoverDelayBinding, in: 0...1000, step: 50)
                    Text("\(hoverDelayMilliseconds) ms")
                        .monospacedDigit()
                        .frame(minWidth: 60, alignment: .trailing)
                }
            }
        }
    }

    private var hoverDelayBinding: Binding<Double> {
        Binding(
            get: { Double(hoverDelayMilliseconds) },
            set: { hoverDelayMilliseconds = Int($0.rounded()) }
        )
    }

    // MARK: - Launch at login

    private var launchAtLoginSection: some View {
        Section {
            Toggle("Launch at login", isOn: launchAtLoginBinding)
            if launchAtLogin.status == .requiresApproval {
                HStack {
                    Text("Approve Topstash in System Settings → Login Items")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Open System Settings") { launchAtLogin.openSystemSettings() }
                }
            }
            if let launchAtLoginError {
                errorText(launchAtLoginError)
            }
        }
    }

    /// Reads the real registration state, so after a failed change the toggle flips back.
    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin.isEnabled },
            set: { enabled in
                do {
                    try launchAtLogin.setEnabled(enabled)
                    launchAtLoginError = nil
                } catch {
                    launchAtLoginError = "Couldn't change launch at login: \(error.localizedDescription)"
                }
            }
        )
    }

    // MARK: -

    private func errorText(_ message: String) -> some View {
        Text(message)
            .font(.callout)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
    }
}
