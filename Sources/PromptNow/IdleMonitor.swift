import Foundation
import CoreGraphics

final class IdleMonitor {
    var idleThreshold: TimeInterval = 60

    var isUserActive: Bool {
        systemIdleTime < idleThreshold
    }

    private var systemIdleTime: TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: UInt32.max)!)
    }
}
