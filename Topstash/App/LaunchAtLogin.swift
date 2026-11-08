import Observation
import ServiceManagement

/// Launch at login through `SMAppService.mainApp`. Nothing is stored: the state is always read
/// from the system, because the user can also change it in System Settings → Login Items.
@MainActor @Observable
final class LaunchAtLogin {
    private(set) var status: SMAppService.Status

    var isEnabled: Bool { status == .enabled }

    init() {
        status = SMAppService.mainApp.status
    }

    /// Registers or unregisters the app, then reads the real state again, also when this throws.
    func setEnabled(_ enabled: Bool) throws {
        defer { refresh() }
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    func refresh() {
        status = SMAppService.mainApp.status
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
