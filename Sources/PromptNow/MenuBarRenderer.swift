import AppKit
import PromptNowCore

struct MenuBarBadgeContent {
    var iconName: String
    var iconImage: NSImage?
    var text: String
    var foregroundColor: NSColor
    var backgroundColor: NSColor
    var borderColor: NSColor
    var accentColor: NSColor
    var progress: Double
}

@MainActor
struct MenuBarRenderer {
    func content(state: ReminderTimerState, phase: Int) -> MenuBarBadgeContent {
        MenuBarBadgeContent(
            iconName: iconName(for: state, phase: phase / 3),
            iconImage: LogoAssets.mark,
            text: labelText(for: state),
            foregroundColor: foregroundColor(for: state),
            backgroundColor: backgroundColor(for: state),
            borderColor: borderColor(for: state),
            accentColor: accentColor(for: state),
            progress: progress(for: state)
        )
    }

    private func labelText(for state: ReminderTimerState) -> String {
        guard state.isEnabled else { return "off" }
        guard state.hasTarget else { return "ready" }
        return ReminderTimerState.format(state.remaining)
    }

    private func iconName(for state: ReminderTimerState, phase: Int) -> String {
        guard state.isEnabled else { return "pause.circle" }
        guard state.hasTarget else { return phase.isMultiple(of: 2) ? "sparkle.magnifyingglass" : "magnifyingglass.circle" }
        guard state.isActive else { return "moon.zzz" }

        let cycle = ["timer", "hourglass", "sparkle.magnifyingglass"]
        return cycle[phase % cycle.count]
    }

    private func foregroundColor(for state: ReminderTimerState) -> NSColor {
        guard state.isEnabled else { return NSColor.white.withAlphaComponent(0.68) }
        guard state.hasTarget else { return NSColor.white.withAlphaComponent(0.82) }
        guard state.isActive else { return NSColor.white.withAlphaComponent(0.76) }
        return NSColor.white.withAlphaComponent(0.96)
    }

    private func backgroundColor(for state: ReminderTimerState) -> NSColor {
        guard state.isEnabled else { return NSColor(calibratedWhite: 0.02, alpha: 0.78) }
        return NSColor(calibratedWhite: 0.02, alpha: 0.82)
    }

    private func borderColor(for state: ReminderTimerState) -> NSColor {
        guard state.isEnabled else { return NSColor.white.withAlphaComponent(0.14) }
        return NSColor.white.withAlphaComponent(0.28)
    }

    private func accentColor(for state: ReminderTimerState) -> NSColor {
        guard state.isEnabled else { return NSColor.white.withAlphaComponent(0.30) }
        guard state.hasTarget else { return NSColor.systemPink.withAlphaComponent(0.82) }
        guard state.isActive else { return NSColor.systemIndigo.withAlphaComponent(0.80) }
        return NSColor.systemPink.withAlphaComponent(0.95)
    }

    private func progress(for state: ReminderTimerState) -> Double {
        guard state.interval > 0 else { return 0 }
        return min(1, max(0, (state.interval - state.remaining) / state.interval))
    }
}
