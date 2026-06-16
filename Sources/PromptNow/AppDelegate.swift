import AppKit
import Foundation
import PromptNowCore
import ServiceManagement
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let settings = SettingsStore()
    private let targetTracker = TargetTracker()
    private let windowFocuser = WindowFocuser()
    private let idleMonitor = IdleMonitor()
    private let launchAtLogin = LaunchAtLoginController()
    private let menuBarRenderer = MenuBarRenderer()

    private var statusItem: NSStatusItem!
    private var statusView: MenuBarStatusView!
    private var timer: Timer?
    private var reminderState: ReminderTimerState
    private var lastTickDate = Date()
    private var nudgeIndex = 0
    private var menuBarPhase = 0
    private var controlPopover: NSPopover?
    private var controlPanelView: PromptPanelView?
    private var nudgePopover: NSPopover?
    private var notificationsEnabled = false

    override init() {
        reminderState = ReminderTimerState(
            interval: settings.interval,
            isEnabled: settings.isEnabled,
            hasTarget: settings.lastTarget != nil,
            isActive: true
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureNotifications()
        configureStatusItem()
        configureObservers()
        restoreLastTarget()
        startClock()
        renderMenu()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.showControlPanel()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }

    private func configureNotifications() {
        guard AppRuntime.isRunningFromAppBundle else {
            notificationsEnabled = false
            return
        }

        notificationsEnabled = true
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: MenuBarStatusView.badgeWidth)
        statusView = MenuBarStatusView(frame: NSRect(x: 0, y: 0, width: MenuBarStatusView.badgeWidth, height: NSStatusBar.system.thickness))
        statusView.target = self
        statusView.action = #selector(toggleControlPanel)
        statusItem.view = statusView
    }

    private func configureObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(frontmostApplicationChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceActivityChanged(_:)),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceActivityChanged(_:)),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
    }

    private func restoreLastTarget() {
        if let savedTarget = settings.lastTarget {
            targetTracker.restore(savedTarget)
            reminderState.hasTarget = true
        }

        if let frontmost = NSWorkspace.shared.frontmostApplication {
            recordTargetIfNeeded(frontmost)
        }
    }

    private func startClock() {
        lastTickDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.clockTick()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func clockTick() {
        let now = Date()
        let elapsed = min(now.timeIntervalSince(lastTickDate), 5)
        lastTickDate = now

        reminderState.isActive = idleMonitor.isUserActive
        reminderState.hasTarget = targetTracker.lastTarget != nil
        menuBarPhase += 1

        if reminderState.tick(by: elapsed) == .fired {
            fireReminder()
        }

        renderMenuTitle()
    }

    private func fireReminder() {
        guard let target = targetTracker.lastTarget else { return }
        windowFocuser.focus(target)
        showReminderNotification(for: target)
        showNudgePanel(for: target)
        nudgeIndex += 1
    }

    private func showReminderNotification(for target: StoredTarget) {
        guard notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Prompt Now"
        content.body = "\(target.displayName) is ready for another pass."
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "prompt-now-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func showNudgePanel(for target: StoredTarget) {
        guard let anchorView = statusAnchorView else { return }

        let alert = NSAlert()
        alert.messageText = "Back to \(target.displayName)"
        alert.informativeText = NudgeCopy.line(for: nudgeIndex)
        alert.addButton(withTitle: "Prompt again")
        alert.addButton(withTitle: "Snooze")
        alert.alertStyle = .informational

        let popover = NSPopover()
        let controller = NSViewController()
        let hostingView = AlertHostView(alert: alert, onClose: {
            popover.performClose(nil)
        })
        controller.view = hostingView
        popover.contentViewController = controller
        popover.behavior = .transient
        popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
        nudgePopover = popover
    }

    private func renderMenu() {
        renderMenuTitle()
        updateControlPanel()
    }

    private func updateControlPanel() {
        controlPanelView?.update(
            state: reminderState,
            statusLine: statusLine,
            targetName: targetTracker.lastTarget?.displayName,
            launchTitle: launchAtLogin.menuTitle,
            launchEnabled: launchAtLogin.canManage,
            accessibilityEnabled: WindowFocuser.canUseAccessibilityFeatures,
            nudge: NudgeCopy.line(for: nudgeIndex)
        )
    }

    @objc private func toggleControlPanel() {
        if let controlPopover, controlPopover.isShown {
            controlPopover.performClose(nil)
            return
        }

        showControlPanel()
    }

    private func showControlPanel() {
        guard let anchorView = statusAnchorView else { return }

        let panel = PromptPanelView(initialInterval: reminderState.interval)
        panel.onToggleEnabled = { [weak self] in self?.toggleEnabled() }
        panel.onOpenTarget = { [weak self] in self?.openLastTargetNow() }
        panel.onResetTimer = { [weak self] in self?.resetTimer() }
        panel.onSnoozeTimer = { [weak self] in self?.snoozeTimer() }
        panel.onSetTimer = { [weak self] seconds in self?.setTimer(seconds) }
        panel.onToggleLaunchAtLogin = { [weak self] in self?.toggleLaunchAtLogin() }
        panel.onOpenAccessibility = { [weak self] in self?.openAccessibilitySettings() }
        panel.onQuit = { [weak self] in self?.quit() }

        let controller = NSViewController()
        controller.view = panel

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = panel.frame.size
        popover.contentViewController = controller

        controlPanelView = panel
        controlPopover = popover
        updateControlPanel()
        popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
    }

    private func renderMenuTitle() {
        statusView?.update(menuBarRenderer.content(state: reminderState, phase: menuBarPhase))
    }

    private var statusAnchorView: NSView? {
        statusView ?? statusItem?.button
    }

    private var statusLine: String {
        if !reminderState.isEnabled {
            return "Taking a tiny nap."
        }
        if targetTracker.lastTarget == nil {
            return "Waiting for Codex or Claude."
        }
        if !reminderState.isActive {
            return "Paused while you are away."
        }
        return "Next review in \(ReminderTimerState.format(reminderState.remaining))."
    }

    private func timerSubmenu() -> NSMenuItem {
        let parent = NSMenuItem(title: "Timer", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let presets: [(String, TimeInterval)] = [
            ("5 minutes", 5 * 60),
            ("10 minutes", 10 * 60),
            ("15 minutes", 15 * 60),
            ("25 minutes", 25 * 60),
            ("45 minutes", 45 * 60),
            ("60 minutes", 60 * 60)
        ]

        for preset in presets {
            let item = NSMenuItem(title: preset.0, action: #selector(selectTimerPreset(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset.1
            item.state = abs(reminderState.interval - preset.1) < 0.5 ? .on : .off
            submenu.addItem(item)
        }

        submenu.addItem(.separator())

        let custom = NSMenuItem(title: "Custom...", action: #selector(selectCustomTimer), keyEquivalent: "")
        custom.target = self
        submenu.addItem(custom)

        parent.submenu = submenu
        return parent
    }

    @objc private func frontmostApplicationChanged(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        recordTargetIfNeeded(app)
    }

    @objc private func workspaceActivityChanged(_ notification: Notification) {
        lastTickDate = Date()
    }

    private func recordTargetIfNeeded(_ app: NSRunningApplication) {
        guard TargetMatcher.isPromptTarget(
            name: app.localizedName ?? app.bundleIdentifier ?? "",
            bundleIdentifier: app.bundleIdentifier
        ) else {
            return
        }

        let target = targetTracker.record(app)
        settings.lastTarget = target
        reminderState.hasTarget = true
        renderMenu()
    }

    @objc private func toggleEnabled() {
        reminderState.isEnabled.toggle()
        settings.isEnabled = reminderState.isEnabled
        renderMenu()
    }

    @objc private func openLastTargetNow() {
        guard let target = targetTracker.lastTarget else { return }
        windowFocuser.focus(target)
    }

    @objc private func selectTimerPreset(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? TimeInterval else { return }
        setTimer(seconds)
    }

    private func setTimer(_ seconds: TimeInterval) {
        reminderState.setInterval(seconds)
        settings.interval = reminderState.interval
        renderMenu()
    }

    private func resetTimer() {
        reminderState.reset()
        renderMenu()
    }

    private func snoozeTimer() {
        reminderState.isEnabled = true
        settings.isEnabled = true
        reminderState.reset()
        renderMenu()
    }

    @objc private func selectCustomTimer() {
        let alert = NSAlert()
        alert.messageText = "Set review timer"
        alert.informativeText = "Choose a timer between 1 and 180 minutes."
        alert.addButton(withTitle: "Set")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        input.placeholderString = "15"
        input.stringValue = "\(Int(reminderState.interval / 60))"
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            let minutes = min(180, max(1, input.integerValue))
            let seconds = TimeInterval(minutes * 60)
            reminderState.setInterval(seconds)
            settings.interval = seconds
            renderMenu()
        }
    }

    @objc private func toggleLaunchAtLogin() {
        launchAtLogin.setEnabled(!launchAtLogin.isEnabled)
        renderMenu()
    }

    @objc private func openAccessibilitySettings() {
        windowFocuser.openAccessibilitySettings()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
