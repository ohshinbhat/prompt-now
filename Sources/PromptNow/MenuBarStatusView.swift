import AppKit

@MainActor
final class MenuBarStatusView: NSControl {
    static let badgeWidth: CGFloat = 118

    private var content = MenuBarBadgeContent(
        iconName: "timer",
        iconImage: nil,
        text: "00:30",
        foregroundColor: .white,
        backgroundColor: NSColor(calibratedWhite: 0.02, alpha: 0.82),
        borderColor: NSColor.white.withAlphaComponent(0.28),
        accentColor: NSColor.systemPink.withAlphaComponent(0.95),
        progress: 0
    )

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.badgeWidth, height: NSStatusBar.system.thickness)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        toolTip = "Prompt Now"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(_ content: MenuBarBadgeContent) {
        self.content = content
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bodyRect = NSRect(
            x: 4,
            y: max(3.5, (bounds.height - 20) / 2),
            width: bounds.width - 14,
            height: 20
        )
        let terminalRect = NSRect(
            x: bodyRect.maxX + 2,
            y: bodyRect.midY - 5,
            width: 5,
            height: 10
        )

        drawBatteryBody(in: bodyRect, terminalRect: terminalRect)
        drawProgress(in: bodyRect)
        drawChrome(in: bodyRect, terminalRect: terminalRect)
        drawIcon(in: bodyRect)
        drawText(in: bodyRect)
    }

    private func drawBatteryBody(in bodyRect: NSRect, terminalRect: NSRect) {
        let body = NSBezierPath(roundedRect: bodyRect, xRadius: 10, yRadius: 10)
        content.backgroundColor.setFill()
        body.fill()

        let terminal = NSBezierPath(roundedRect: terminalRect, xRadius: 2.5, yRadius: 2.5)
        content.backgroundColor.setFill()
        terminal.fill()
    }

    override func mouseDown(with event: NSEvent) {
        sendAction(action, to: target)
    }

    override func rightMouseDown(with event: NSEvent) {
        sendAction(action, to: target)
    }

    private func drawIcon(in bodyRect: NSRect) {
        guard let image = content.iconImage ?? NSImage(systemSymbolName: content.iconName, accessibilityDescription: "Prompt Now") else {
            return
        }

        let tintedImage = image.tinted(with: content.foregroundColor)
        let iconSize: CGFloat = 11
        let textWidth = textSize().width
        let contentWidth = iconSize + 7 + textWidth
        let startX = bodyRect.midX - contentWidth / 2
        let iconRect = NSRect(
            x: startX,
            y: bodyRect.midY - iconSize / 2,
            width: iconSize,
            height: iconSize
        )

        tintedImage.draw(
            in: iconRect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: nil
        )
    }

    private func drawProgress(in bodyRect: NSRect) {
        guard content.progress > 0 else { return }

        let innerRect = bodyRect.insetBy(dx: 2.5, dy: 2.5)
        let fillRect = NSRect(
            x: innerRect.minX,
            y: innerRect.minY,
            width: innerRect.width * min(1, max(0, content.progress)),
            height: innerRect.height
        )
        let fill = NSBezierPath(roundedRect: fillRect, xRadius: 7.5, yRadius: 7.5)
        content.accentColor.withAlphaComponent(0.44).setFill()

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: innerRect, xRadius: 7.5, yRadius: 7.5).addClip()
        fill.fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawChrome(in bodyRect: NSRect, terminalRect: NSRect) {
        let body = NSBezierPath(roundedRect: bodyRect, xRadius: 10, yRadius: 10)
        content.borderColor.setStroke()
        body.lineWidth = 0.8
        body.stroke()

        let terminal = NSBezierPath(roundedRect: terminalRect, xRadius: 2.5, yRadius: 2.5)
        content.borderColor.withAlphaComponent(0.75).setStroke()
        terminal.lineWidth = 0.7
        terminal.stroke()

        let shineRect = NSRect(x: bodyRect.minX + 9, y: bodyRect.maxY - 5, width: bodyRect.width - 18, height: 1)
        NSColor.white.withAlphaComponent(0.10).setFill()
        NSBezierPath(roundedRect: shineRect, xRadius: 0.5, yRadius: 0.5).fill()
    }

    private func drawText(in bodyRect: NSRect) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byClipping

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
        shadow.shadowBlurRadius = 1
        shadow.shadowOffset = NSSize(width: 0, height: -0.4)

        let font = timerFont()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: content.foregroundColor,
            .paragraphStyle: paragraphStyle,
            .shadow: shadow
        ]

        let measured = textSize()
        let iconSize: CGFloat = 11
        let contentWidth = iconSize + 7 + measured.width
        let startX = bodyRect.midX - contentWidth / 2
        let textRect = NSRect(
            x: startX + iconSize + 7,
            y: bodyRect.midY - measured.height / 2 - 0.5,
            width: measured.width + 1,
            height: measured.height + 1
        )
        NSString(string: content.text).draw(in: textRect, withAttributes: attributes)
    }

    private func textSize() -> NSSize {
        NSString(string: content.text).size(withAttributes: [.font: timerFont()])
    }

    private func timerFont() -> NSFont {
        let baseFont = NSFont.monospacedDigitSystemFont(ofSize: 12.1, weight: .semibold)
        if let roundedDescriptor = baseFont.fontDescriptor.withDesign(.rounded) {
            return NSFont(descriptor: roundedDescriptor, size: 12.1) ?? baseFont
        }
        return baseFont
    }
}
