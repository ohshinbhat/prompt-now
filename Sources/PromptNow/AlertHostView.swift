import AppKit

final class AlertHostView: NSView {
    private let onClose: () -> Void

    init(alert: NSAlert, onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 116))

        let title = NSTextField(labelWithString: alert.messageText)
        title.font = .boldSystemFont(ofSize: 14)
        title.translatesAutoresizingMaskIntoConstraints = false

        let copy = NSTextField(wrappingLabelWithString: alert.informativeText)
        copy.font = .systemFont(ofSize: 12)
        copy.textColor = .secondaryLabelColor
        copy.translatesAutoresizingMaskIntoConstraints = false

        let button = NSButton(title: alert.buttons.first?.title ?? "Done", target: self, action: #selector(close))
        button.bezelStyle = .rounded
        button.translatesAutoresizingMaskIntoConstraints = false

        addSubview(title)
        addSubview(copy)
        addSubview(button)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            title.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            copy.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            copy.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            copy.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            button.topAnchor.constraint(equalTo: copy.bottomAnchor, constant: 14),
            button.trailingAnchor.constraint(equalTo: title.trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func close() {
        onClose()
    }
}
