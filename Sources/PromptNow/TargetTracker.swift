import AppKit
import Foundation
import PromptNowCore

final class TargetTracker {
    private(set) var lastTarget: StoredTarget?

    func restore(_ target: StoredTarget) {
        lastTarget = target
    }

    @discardableResult
    func record(_ app: NSRunningApplication) -> StoredTarget {
        let appName = app.localizedName ?? app.bundleIdentifier ?? "Codex or Claude"
        let target = StoredTarget(
            displayName: TargetMatcher.normalizedTargetName(name: appName, bundleIdentifier: app.bundleIdentifier),
            appName: appName,
            bundleIdentifier: app.bundleIdentifier,
            processIdentifier: app.processIdentifier,
            windowTitle: nil
        )
        lastTarget = target
        return target
    }
}
