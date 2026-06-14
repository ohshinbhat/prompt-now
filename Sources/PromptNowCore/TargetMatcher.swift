import Foundation

public struct TargetApp: Equatable {
    public var name: String
    public var bundleIdentifier: String?
    public var windowTitle: String?

    public init(name: String, bundleIdentifier: String? = nil, windowTitle: String? = nil) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.windowTitle = windowTitle
    }
}

public enum TargetMatcher {
    private static let appNameNeedles = ["codex", "claude"]
    private static let bundleNeedles = ["codex", "claude", "anthropic"]

    public static func isPromptTarget(name: String, bundleIdentifier: String?) -> Bool {
        let loweredName = name.lowercased()
        if appNameNeedles.contains(where: loweredName.contains) {
            return true
        }

        let loweredBundle = bundleIdentifier?.lowercased() ?? ""
        return bundleNeedles.contains(where: loweredBundle.contains)
    }

    public static func normalizedTargetName(name: String, bundleIdentifier: String?) -> String {
        if isPromptTarget(name: name, bundleIdentifier: bundleIdentifier) {
            let loweredName = name.lowercased()
            if loweredName.contains("claude") {
                return "Claude"
            }
            if loweredName.contains("codex") {
                return "Codex"
            }
        }

        return name
    }
}
