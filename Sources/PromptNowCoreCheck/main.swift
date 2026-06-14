import Foundation
import PromptNowCore

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fatalError("Check failed: \(message)")
    }
}

private func checkReminderTimer() {
    var waiting = ReminderTimerState(interval: 15 * 60, hasTarget: false)
    expect(waiting.tick(by: 60) == .none, "waiting timer should not fire")
    expect(waiting.remaining == 15 * 60, "waiting timer should not count down")
    expect(waiting.statusTitle == "PN waiting", "waiting title")

    var disabled = ReminderTimerState(interval: 15 * 60, isEnabled: false, hasTarget: true)
    expect(disabled.tick(by: 60) == .none, "disabled timer should not fire")
    expect(disabled.remaining == 15 * 60, "disabled timer should not count down")
    expect(disabled.statusTitle == "PN off", "disabled title")

    var inactive = ReminderTimerState(interval: 15 * 60, hasTarget: true, isActive: false)
    expect(inactive.tick(by: 60) == .none, "inactive timer should not fire")
    expect(inactive.remaining == 15 * 60, "inactive timer should pause")

    var firing = ReminderTimerState(interval: 60, hasTarget: true)
    expect(firing.tick(by: 60) == .fired, "timer should fire at zero")
    expect(firing.remaining == 60, "timer should reset after fire")

    expect(ReminderTimerState.format(61) == "01:01", "format exact seconds")
    expect(ReminderTimerState.format(60.1) == "01:01", "format rounds up")
    expect(ReminderTimerState.format(0) == "00:00", "format zero")

    var finalMinute = ReminderTimerState(interval: 120, remaining: 61, hasTarget: true)
    expect(!finalMinute.isInFinalMinute, "not final minute before threshold")
    _ = finalMinute.tick(by: 1)
    expect(finalMinute.isInFinalMinute, "final minute threshold")
}

private func checkTargetMatcher() {
    expect(TargetMatcher.isPromptTarget(name: "Codex", bundleIdentifier: "com.openai.codex"), "Codex app matches")
    expect(TargetMatcher.isPromptTarget(name: "Claude", bundleIdentifier: "com.anthropic.claude"), "Claude app matches")
    expect(TargetMatcher.isPromptTarget(name: "Helper", bundleIdentifier: "com.anthropic.claude.helper"), "Anthropic bundle matches")
    expect(!TargetMatcher.isPromptTarget(name: "Safari", bundleIdentifier: "com.apple.Safari"), "Safari rejected")
    expect(!TargetMatcher.isPromptTarget(name: "Notes", bundleIdentifier: "com.apple.Notes"), "Notes rejected")

    expect(TargetMatcher.normalizedTargetName(name: "Claude", bundleIdentifier: nil) == "Claude", "normalize Claude")
    expect(TargetMatcher.normalizedTargetName(name: "Codex Desktop", bundleIdentifier: nil) == "Codex", "normalize Codex")
    expect(TargetMatcher.normalizedTargetName(name: "Notes", bundleIdentifier: nil) == "Notes", "preserve unrelated name")
}

checkReminderTimer()
checkTargetMatcher()
print("PromptNowCoreCheck passed")
