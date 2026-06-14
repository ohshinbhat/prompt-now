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

    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var reminderState: ReminderTimerState
    private var lastTickDate = Date()
    private var nudgeIndex = 0
    private var activePopover: NSPopover?
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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "sparkle.magnifyingglass", accessibilityDescription: "Prompt Now")
        statusItem.button?.imagePosition = .imageLeading
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
        guard let button = statusItem.button else { return }

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
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        activePopover = popover
    }

    private func renderMenu() {
        renderMenuTitle()

        let menu = NSMenu()

        let status = NSMenuItem(title: statusLine, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        if let target = targetTracker.lastTarget {
            let targetItem = NSMenuItem(title: "Last target: \(target.displayName)", action: nil, keyEquivalent: "")
            targetItem.isEnabled = false
            menu.addItem(targetItem)
        } else {
            let waitingItem = NSMenuItem(title: "Open Codex or Claude to start", action: nil, keyEquivalent: "")
            waitingItem.isEnabled = false
            menu.addItem(waitingItem)
        }

        menu.addItem(.separator())

        let toggle = NSMenuItem(
            title: reminderState.isEnabled ? "Turn reminders off" : "Turn reminders on",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)

        let openNow = NSMenuItem(title: "Open last target now", action: #selector(openLastTargetNow), keyEquivalent: "o")
        openNow.target = self
        openNow.isEnabled = targetTracker.lastTarget != nil
        menu.addItem(openNow)

        menu.addItem(timerSubmenu())

        menu.addItem(.separator())

        let launchItem = NSMenuItem(
            title: launchAtLogin.menuTitle,
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.isEnabled = launchAtLogin.canManage
        menu.addItem(launchItem)

        let permissionItem = NSMenuItem(title: "Accessibility permission...", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        permissionItem.target = self
        menu.addItem(permissionItem)

        menu.addItem(.separator())

        let nudge = NSMenuItem(title: NudgeCopy.line(for: nudgeIndex), action: nil, keyEquivalent: "")
        nudge.isEnabled = false
        menu.addItem(nudge)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Prompt Now", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func renderMenuTitle() {
        guard let button = statusItem?.button else { return }
        let pulse = reminderState.isInFinalMinute && Int(Date().timeIntervalSince1970) % 2 == 0 ? " *" : ""
        button.title = "\(reminderState.statusTitle)\(pulse)"
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
        reminderState.setInterval(seconds)
        settings.interval = seconds
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
