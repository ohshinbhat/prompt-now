import Foundation

public enum ReminderTimerEvent: Equatable {
    case none
    case fired
}

public struct ReminderTimerState: Equatable {
    public var interval: TimeInterval
    public var remaining: TimeInterval
    public var isEnabled: Bool
    public var hasTarget: Bool
    public var isActive: Bool

    public init(
        interval: TimeInterval,
        remaining: TimeInterval? = nil,
        isEnabled: Bool = true,
        hasTarget: Bool = false,
        isActive: Bool = true
    ) {
        let clampedInterval = max(1, interval)
        self.interval = clampedInterval
        self.remaining = remaining ?? clampedInterval
        self.isEnabled = isEnabled
        self.hasTarget = hasTarget
        self.isActive = isActive
    }

    public var shouldCountDown: Bool {
        isEnabled && hasTarget && isActive
    }

    public var statusTitle: String {
        guard isEnabled else { return "PN off" }
        guard hasTarget else { return "PN waiting" }
        return "PN \(Self.format(remaining))"
    }

    public var isInFinalMinute: Bool {
        shouldCountDown && remaining <= 60
    }

    public mutating func setInterval(_ seconds: TimeInterval) {
        interval = max(1, seconds)
        remaining = interval
    }

    public mutating func reset() {
        remaining = interval
    }

    public mutating func tick(by seconds: TimeInterval) -> ReminderTimerEvent {
        guard shouldCountDown else { return .none }
        remaining = max(0, remaining - max(0, seconds))

        if remaining <= 0 {
            remaining = interval
            return .fired
        }

        return .none
    }

    public static func format(_ seconds: TimeInterval) -> String {
        let wholeSeconds = max(0, Int(seconds.rounded(.up)))
        let hours = wholeSeconds / 3_600
        let minutes = (wholeSeconds % 3_600) / 60
        let seconds = wholeSeconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
