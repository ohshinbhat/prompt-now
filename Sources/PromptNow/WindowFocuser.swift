import AppKit
import ApplicationServices
import Foundation

final class WindowFocuser {
    func focus(_ target: StoredTarget) {
        if let runningApp = runningApplication(for: target) {
            runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            raiseFrontWindow(for: runningApp)
            return
        }

        if let bundleIdentifier = target.bundleIdentifier,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
        }
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func runningApplication(for target: StoredTarget) -> NSRunningApplication? {
        if let pid = target.processIdentifier,
           let app = NSRunningApplication(processIdentifier: pid),
           !app.isTerminated {
            return app
        }

        if let bundleIdentifier = target.bundleIdentifier {
            return NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
        }

        return NSWorkspace.shared.runningApplications.first {
            $0.localizedName == target.appName
        }
    }

    private func raiseFrontWindow(for app: NSRunningApplication) {
        guard AXIsProcessTrusted() else { return }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedWindow: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
           let focusedWindow {
            AXUIElementPerformAction(focusedWindow as! AXUIElement, kAXRaiseAction as CFString)
        }
    }
}
