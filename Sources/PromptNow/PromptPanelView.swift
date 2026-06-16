import AppKit
import PromptNowCore

@MainActor
final class PromptPanelView: NSView {
    var onToggleEnabled: (() -> Void)?
    var onOpenTarget: (() -> Void)?
    var onResetTimer: (() -> Void)?
    var onSnoozeTimer: (() -> Void)?
    var onSetTimer: ((TimeInterval) -> Void)?
    var onToggleLaunchAtLogin: (() -> Void)?
    var onOpenAccessibility: (() -> Void)?
    var onQuit: (() -> Void)?

    private let accentColor = NSColor.systemPink
    private let titleLabel = NSTextField(labelWithString: "Prompt Now")
    private let stateLabel = NSTextField(labelWithString: "Review loop")
    private let timerLabel = NSTextField(labelWithString: "00:30")
    private let intervalLabel = NSTextField(labelWithString: "Review every 30 sec")
    private let targetLabel = NSTextField(labelWithString: "Open Codex or Claude once to connect.")
    private let timeSliderView = PromptTimeSliderView()
    private let timeInput = NSTextField(string: "30")
    private let unitPopup = NSPopUpButton()
    private var selectedUnit: PromptTimeUnit = .seconds
    private var currentInterval: TimeInterval = 30
    private let enabledButton = NSButton(title: "Pause", target: nil, action: nil)
    private let resetButton = NSButton(title: "Reset", target: nil, action: nil)
    private let snoozeButton = NSButton(title: "Snooze", target: nil, action: nil)
    private let openTargetButton = NSButton(title: "Open", target: nil, action: nil)
    private let launchButton = NSButton(title: "Login: Off", target: nil, action: nil)
    private let accessibilityButton = NSButton(title: "Access", target: nil, action: nil)

    init(initialInterval: TimeInterval) {
        super.init(frame: NSRect(x: 0, y: 0, width: 320, height: 420))
        configureChrome()
        buildLayout()
        setIntervalInput(initialInterval)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(
        state: ReminderTimerState,
        statusLine: String,
        targetName: String?,
        launchTitle: String,
        launchEnabled: Bool,
        accessibilityEnabled: Bool,
        nudge: String
    ) {
        currentInterval = state.interval
        timerLabel.stringValue = countdownText(for: state.remaining)
        intervalLabel.stringValue = "Review every \(shortTime(state.interval))"
        stateLabel.stringValue = stateCaption(for: state, nudge: nudge)
        targetLabel.stringValue = targetName.map { "Target: \($0)" } ?? "Open Codex or Claude once to connect."
        timeSliderView.update(unit: selectedUnit, value: selectedUnit.value(from: state.interval), accentColor: accent(for: state))
        enabledButton.title = state.isEnabled ? "Pause" : "Resume"
        openTargetButton.isEnabled = targetName != nil
        launchButton.title = launchTitle.replacingOccurrences(of: "Launch at login", with: "Login")
        launchButton.isEnabled = launchEnabled
        accessibilityButton.isHidden = !accessibilityEnabled
        accessibilityButton.isEnabled = accessibilityEnabled
    }

    private func configureChrome() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedWhite: 0.04, alpha: 0.96).cgColor
        layer?.cornerRadius = 28
        layer?.masksToBounds = true
    }

    private func buildLayout() {
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 14
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: topAnchor, constant: 22),
            root.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            root.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            root.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -20)
        ])

        root.addArrangedSubview(makeHeader())
        root.addArrangedSubview(makeHero())
        root.addArrangedSubview(makeSliderBlock())
        root.addArrangedSubview(makePrimaryActionRow())
        root.addArrangedSubview(makeTimerForm())
        root.addArrangedSubview(makePresetRow())
        root.addArrangedSubview(makeTargetRow())
        root.addArrangedSubview(makeSecondaryActionRow())

    }

    private func makeHeader() -> NSView {
        let mark = NSImageView()
        mark.image = LogoAssets.mark?.tinted(with: accentColor) ?? NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)
        mark.imageScaling = .scaleProportionallyUpOrDown
        mark.translatesAutoresizingMaskIntoConstraints = false
        mark.widthAnchor.constraint(equalToConstant: 20).isActive = true
        mark.heightAnchor.constraint(equalToConstant: 20).isActive = true
        mark.setContentHuggingPriority(.required, for: .horizontal)

        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .white.withAlphaComponent(0.78)

        stateLabel.font = .systemFont(ofSize: 13, weight: .medium)
        stateLabel.textColor = .white.withAlphaComponent(0.58)
        stateLabel.lineBreakMode = .byTruncatingTail

        let left = NSStackView(views: [mark, titleLabel])
        left.orientation = .horizontal
        left.alignment = .centerY
        left.spacing = 8

        let row = NSStackView(views: [left, stateLabel])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .equalSpacing
        row.widthAnchor.constraint(equalToConstant: 276).isActive = true
        return row
    }

    private func makeHero() -> NSView {
        timerLabel.font = roundedFont(size: 52, weight: .heavy)
        timerLabel.textColor = .white

        intervalLabel.font = .systemFont(ofSize: 15, weight: .medium)
        intervalLabel.textColor = .white.withAlphaComponent(0.72)

        let stack = NSStackView(views: [timerLabel, intervalLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.widthAnchor.constraint(equalToConstant: 276).isActive = true
        return stack
    }

    private func makeSliderBlock() -> NSView {
        timeSliderView.onValueChange = { [weak self] value in
            guard let self else { return }
            let seconds = selectedUnit.seconds(from: value)
            currentInterval = seconds
            timeInput.stringValue = "\(Int(value.rounded()))"
            onSetTimer?(seconds)
        }
        timeSliderView.translatesAutoresizingMaskIntoConstraints = false
        timeSliderView.widthAnchor.constraint(equalToConstant: 276).isActive = true
        timeSliderView.heightAnchor.constraint(equalToConstant: 82).isActive = true
        return timeSliderView
    }

    private func makeTimerForm() -> NSView {
        let label = smallLabel("Review every")
        label.setContentCompressionResistancePriority(.required, for: .horizontal)

        timeInput.alignment = .center
        timeInput.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        timeInput.drawsBackground = true
        timeInput.backgroundColor = NSColor.white.withAlphaComponent(0.10)
        timeInput.textColor = .white
        timeInput.translatesAutoresizingMaskIntoConstraints = false
        timeInput.widthAnchor.constraint(equalToConstant: 86).isActive = true

        unitPopup.addItems(withTitles: PromptTimeUnit.allCases.map(\.title))
        unitPopup.target = self
        unitPopup.action = #selector(unitChanged)
        unitPopup.translatesAutoresizingMaskIntoConstraints = false
        unitPopup.widthAnchor.constraint(equalToConstant: 118).isActive = true

        let setButton = pillButton("Set", action: #selector(saveTimer), isAccent: true)
        setButton.widthAnchor.constraint(equalToConstant: 54).isActive = true

        let controls = NSStackView(views: [timeInput, unitPopup, setButton])
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 8

        let stack = NSStackView(views: [label, controls])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.widthAnchor.constraint(equalToConstant: 276).isActive = true
        return stack
    }

    private func makePresetRow() -> NSView {
        let presets: [(String, TimeInterval)] = [
            ("30s", 30),
            ("5m", 5 * 60),
            ("15m", 15 * 60),
            ("25m", 25 * 60)
        ]
        let buttons = presets.map { title, seconds in
            let button = pillButton(title, action: #selector(selectPreset(_:)), isAccent: false)
            button.tag = Int(seconds)
            button.widthAnchor.constraint(equalToConstant: 63).isActive = true
            return button
        }

        let row = NSStackView(views: buttons)
        row.orientation = .horizontal
        row.spacing = 8
        row.widthAnchor.constraint(equalToConstant: 276).isActive = true
        return row
    }

    private func makeTargetRow() -> NSView {
        targetLabel.font = .systemFont(ofSize: 12, weight: .medium)
        targetLabel.textColor = .white.withAlphaComponent(0.62)
        targetLabel.lineBreakMode = .byTruncatingMiddle
        targetLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [targetLabel])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.widthAnchor.constraint(equalToConstant: 276).isActive = true
        return row
    }

    private func makePrimaryActionRow() -> NSView {
        enabledButton.target = self
        enabledButton.action = #selector(toggleEnabled)
        enabledButton.bezelStyle = .rounded

        resetButton.target = self
        resetButton.action = #selector(resetTimer)
        resetButton.bezelStyle = .rounded

        snoozeButton.target = self
        snoozeButton.action = #selector(snoozeTimer)
        snoozeButton.bezelStyle = .rounded

        openTargetButton.target = self
        openTargetButton.action = #selector(openTarget)
        openTargetButton.bezelStyle = .rounded

        let row = NSStackView(views: [enabledButton, resetButton, snoozeButton, openTargetButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fillEqually
        row.spacing = 8
        row.widthAnchor.constraint(equalToConstant: 276).isActive = true
        return row
    }

    private func makeSecondaryActionRow() -> NSView {
        launchButton.target = self
        launchButton.action = #selector(toggleLaunchAtLogin)
        launchButton.bezelStyle = .rounded

        accessibilityButton.target = self
        accessibilityButton.action = #selector(openAccessibility)
        accessibilityButton.bezelStyle = .rounded

        let quit = NSButton(title: "Quit", target: self, action: #selector(quit))
        quit.bezelStyle = .rounded

        let row = NSStackView(views: [launchButton, accessibilityButton, quit])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fillEqually
        row.spacing = 8
        row.widthAnchor.constraint(equalToConstant: 276).isActive = true
        return row
    }

    private func smallLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white.withAlphaComponent(0.62)
        return label
    }

    private func pillButton(_ title: String, action: Selector, isAccent: Bool) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 12, weight: .semibold)
        button.contentTintColor = isAccent ? accentColor : .white.withAlphaComponent(0.86)
        return button
    }

    private func roundedFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let base = NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        if let descriptor = base.fontDescriptor.withDesign(.rounded) {
            return NSFont(descriptor: descriptor, size: size) ?? base
        }
        return base
    }

    private func setIntervalInput(_ interval: TimeInterval) {
        currentInterval = interval
        selectedUnit = PromptTimeUnit.bestFit(for: interval, preferred: selectedUnit)
        let value = selectedUnit.value(from: interval)
        timeInput.stringValue = "\(Int(value.rounded()))"
        unitPopup.selectItem(withTitle: selectedUnit.title)
        timeSliderView.update(unit: selectedUnit, value: value, accentColor: accentColor)
    }

    private func stateCaption(for state: ReminderTimerState, nudge: String) -> String {
        if !state.isEnabled { return "Paused" }
        if !state.hasTarget { return "Waiting" }
        if !state.isActive { return "Away" }
        return nudge
    }

    private func shortTime(_ seconds: TimeInterval) -> String {
        let rounded = max(0, Int(seconds.rounded(.up)))
        if rounded < 60 { return "\(rounded) sec" }
        if rounded < 60 * 60 { return "\(max(1, rounded / 60)) min" }
        return "\(rounded / 3600) hr"
    }

    private func countdownText(for seconds: TimeInterval) -> String {
        let rounded = max(0, Int(seconds.rounded(.up)))
        if rounded < 60 { return "\(rounded)s" }
        return ReminderTimerState.format(seconds)
    }

    private func accent(for state: ReminderTimerState) -> NSColor {
        if !state.isEnabled { return .white.withAlphaComponent(0.34) }
        if !state.hasTarget { return .systemOrange }
        return accentColor
    }

    @objc private func saveTimer() {
        syncSelectedUnitFromPopup()
        let rawValue = min(selectedUnit.maximumValue, max(0, timeInput.doubleValue))
        let seconds = selectedUnit.seconds(from: rawValue)
        currentInterval = seconds
        timeInput.stringValue = "\(Int(rawValue.rounded()))"
        timeSliderView.update(unit: selectedUnit, value: rawValue, accentColor: accentColor)
        onSetTimer?(seconds)
    }

    @objc private func unitChanged() {
        let previousInterval = currentInterval
        syncSelectedUnitFromPopup()
        let value = selectedUnit.value(from: previousInterval)
        let clampedValue = min(selectedUnit.maximumValue, max(0, value))
        timeInput.stringValue = "\(Int(clampedValue.rounded()))"
        timeSliderView.update(unit: selectedUnit, value: clampedValue, accentColor: accentColor)
    }

    @objc private func selectPreset(_ sender: NSButton) {
        let seconds = TimeInterval(sender.tag)
        setIntervalInput(seconds)
        onSetTimer?(seconds)
    }

    @objc private func toggleEnabled() { onToggleEnabled?() }
    @objc private func resetTimer() { onResetTimer?() }
    @objc private func snoozeTimer() { onSnoozeTimer?() }
    @objc private func openTarget() { onOpenTarget?() }
    @objc private func toggleLaunchAtLogin() { onToggleLaunchAtLogin?() }
    @objc private func openAccessibility() { onOpenAccessibility?() }
    @objc private func quit() { onQuit?() }

    private func syncSelectedUnitFromPopup() {
        selectedUnit = PromptTimeUnit(title: unitPopup.titleOfSelectedItem) ?? selectedUnit
    }
}

@MainActor
final class PromptTimeSliderView: NSControl {
    var onValueChange: ((Double) -> Void)?

    private var unit: PromptTimeUnit = .seconds
    private var value: Double = 30
    private var accentColor: NSColor = .systemPink

    func update(unit: PromptTimeUnit, value: Double, accentColor: NSColor) {
        self.unit = unit
        self.value = min(unit.maximumValue, max(0, value))
        self.accentColor = accentColor
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.68)
        ]

        drawTickLabel("0", x: 0, attributes: labelAttributes)
        drawTickLabel(unit.middleLabel, x: bounds.midX - 10, attributes: labelAttributes)
        drawTickLabel(unit.maxLabel, x: bounds.maxX - 30, attributes: labelAttributes)

        let railRect = NSRect(x: 0, y: 9, width: bounds.width, height: 42)
        let rail = NSBezierPath(roundedRect: railRect, xRadius: 12, yRadius: 12)
        NSColor.white.withAlphaComponent(0.07).setFill()
        rail.fill()
        NSColor.white.withAlphaComponent(0.14).setStroke()
        rail.lineWidth = 1
        rail.stroke()

        drawSubTicks(in: railRect)

        let fillWidth = railRect.width * sliderPosition(for: value)
        if fillWidth > 1 {
            let fillRect = NSRect(x: railRect.minX, y: railRect.minY, width: fillWidth, height: railRect.height)
            let fill = NSBezierPath(roundedRect: fillRect, xRadius: 12, yRadius: 12)
            accentColor.setFill()
            fill.fill()
        }

        let handleX = railRect.minX + railRect.width * sliderPosition(for: value)
        accentColor.setStroke()
        let handle = NSBezierPath()
        handle.move(to: NSPoint(x: handleX, y: railRect.minY + 8))
        handle.line(to: NSPoint(x: handleX, y: railRect.maxY - 8))
        handle.lineWidth = 2
        handle.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        updateFromEvent(event)
    }

    override func mouseDragged(with event: NSEvent) {
        updateFromEvent(event)
    }

    private func drawTickLabel(_ text: String, x: CGFloat, attributes: [NSAttributedString.Key: Any]) {
        NSString(string: text).draw(at: NSPoint(x: x, y: bounds.maxY - 18), withAttributes: attributes)
    }

    private func drawSubTicks(in railRect: NSRect) {
        NSColor.white.withAlphaComponent(0.08).setStroke()
        for index in 1..<10 {
            let x = railRect.minX + railRect.width * CGFloat(index) / 10
            let tick = NSBezierPath()
            tick.move(to: NSPoint(x: x, y: railRect.minY + 7))
            tick.line(to: NSPoint(x: x, y: railRect.maxY - 7))
            tick.lineWidth = 1
            tick.stroke()
        }
    }

    private func updateFromEvent(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let railRect = NSRect(x: 0, y: 9, width: bounds.width, height: 42)
        let position = min(1, max(0, (point.x - railRect.minX) / railRect.width))
        let newValue = snappedValue(from: position)
        value = newValue
        needsDisplay = true
        onValueChange?(newValue)
    }

    private func sliderPosition(for value: Double) -> Double {
        min(1, max(0, value / unit.maximumValue))
    }

    private func snappedValue(from position: Double) -> Double {
        let raw = min(1, max(0, position)) * unit.maximumValue
        return min(unit.maximumValue, max(0, raw.rounded()))
    }
}

enum PromptTimeUnit: CaseIterable, Equatable {
    case seconds
    case minutes
    case hours

    var title: String {
        switch self {
        case .seconds: return "seconds"
        case .minutes: return "minutes"
        case .hours: return "hours"
        }
    }

    var maximumValue: Double {
        switch self {
        case .seconds, .minutes: return 60
        case .hours: return 48
        }
    }

    var middleLabel: String {
        switch self {
        case .seconds, .minutes: return "30"
        case .hours: return "24"
        }
    }

    var maxLabel: String {
        switch self {
        case .seconds, .minutes: return "60"
        case .hours: return "48"
        }
    }

    init?(title: String?) {
        guard let title else { return nil }
        self.init(title: title)
    }

    init?(title: String) {
        guard let match = Self.allCases.first(where: { $0.title == title }) else {
            return nil
        }
        self = match
    }

    func seconds(from value: Double) -> TimeInterval {
        let clamped = min(maximumValue, max(0, value))
        switch self {
        case .seconds:
            return max(1, clamped)
        case .minutes:
            return max(1, clamped * 60)
        case .hours:
            return max(1, clamped * 60 * 60)
        }
    }

    func value(from seconds: TimeInterval) -> Double {
        switch self {
        case .seconds:
            return min(maximumValue, max(0, seconds))
        case .minutes:
            return min(maximumValue, max(0, seconds / 60))
        case .hours:
            return min(maximumValue, max(0, seconds / 60 / 60))
        }
    }

    static func bestFit(for seconds: TimeInterval, preferred: PromptTimeUnit) -> PromptTimeUnit {
        if seconds >= 60 * 60 {
            return .hours
        }
        if seconds >= 60 {
            return .minutes
        }
        return .seconds
    }
}
