import Foundation
import ServiceManagement

final class LaunchAtLoginController {
    var canManage: Bool {
        AppRuntime.isRunningFromAppBundle
    }

    var menuTitle: String {
        guard canManage else { return "Launch at login: App build only" }
        return isEnabled ? "Launch at login: On" : "Launch at login: Off"
    }

    var isEnabled: Bool {
        guard canManage else { return false }
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    func setEnabled(_ enabled: Bool) {
        guard canManage else { return }
        guard #available(macOS 13.0, *) else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Prompt Now launch-at-login update failed: \(error.localizedDescription)")
        }
    }
}
