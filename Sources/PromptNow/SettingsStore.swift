import Foundation

final class SettingsStore {
    private enum Key {
        static let isEnabled = "isEnabled"
        static let interval = "interval"
        static let lastTarget = "lastTarget"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.isEnabled: true,
            Key.interval: 15 * 60
        ])
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Key.isEnabled) }
        set { defaults.set(newValue, forKey: Key.isEnabled) }
    }

    var interval: TimeInterval {
        get { defaults.double(forKey: Key.interval) }
        set { defaults.set(newValue, forKey: Key.interval) }
    }

    var lastTarget: StoredTarget? {
        get {
            guard let data = defaults.data(forKey: Key.lastTarget) else { return nil }
            return try? JSONDecoder().decode(StoredTarget.self, from: data)
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Key.lastTarget)
            } else {
                defaults.removeObject(forKey: Key.lastTarget)
            }
        }
    }
}
