import AppKit

/// Reusable layout: a vertical stack inside an opaque NSPanel.
/// - Optional icon on the left
/// - Header (bold) at top
/// - Message (regular) below header — supports inline markdown
/// - Custom controlView in the middle (filled by the concrete Control)
/// - Buttons row at bottom-right
final class DialogPanel {
	let panel: NSPanel
	let header: NSTextField
	let message: NSTextField
	let iconView: NSImageView
	let controlView: NSView
	let buttonsRow: NSStackView
	private(set) var buttons: [NSButton] = []
	private var clickedIndex: Int? = nil
	private var keyMonitor: Any?
	private var timeoutTimer: Timer?
	private let timeout: Double
	private let timeoutDefaultButton: String

	init(options: ParsedOptions) {
		timeout = options.double("timeout")
		timeoutDefaultButton = options.string("timeout-default-button").isEmpty
			? options.string("default-button")
			: options.string("timeout-default-button")
		// Window setup.
		let style: NSWindow.StyleMask = [.titled, .closable]
		panel = NSPanel(
			contentRect: NSRect(x: 0, y: 0, width: 480, height: 200),
			styleMask: style,
			backing: .buffered,
			defer: false
		)
		panel.title = options.string("title")
		panel.isOpaque = true
		panel.backgroundColor = .windowBackgroundColor
		panel.hasShadow = true
		panel.becomesKeyOnlyIfNeeded = false
		panel.hidesOnDeactivate = false
		panel.level = options.bool("float", default: true) ? .floating : .normal
		panel.titleVisibility = .visible
		panel.titlebarAppearsTransparent = false

		// Icon.
		iconView = NSImageView()
		iconView.translatesAutoresizingMaskIntoConstraints = false
		iconView.imageScaling = .scaleProportionallyUpOrDown
		let icon = IconLoader.resolve(
			name: options.string("icon"),
			file: options.string("icon-file")
		)
		iconView.image = icon
		iconView.isHidden = (icon == nil)

		// Header / message.
		header = NSTextField(labelWithString: "")
		header.font = .boldSystemFont(ofSize: NSFont.systemFontSize + 2)
		header.translatesAutoresizingMaskIntoConstraints = false
		header.isHidden = options.string("header").isEmpty
		header.lineBreakMode = .byWordWrapping
		header.maximumNumberOfLines = 0
		header.preferredMaxLayoutWidth = 440
		header.allowsEditingTextAttributes = true
		header.isSelectable = true
		if !header.isHidden {
			header.attributedStringValue = Markdown.attributed(
				options.string("header"),
				font: .boldSystemFont(ofSize: NSFont.systemFontSize + 2)
			)
		}

		message = NSTextField(labelWithString: "")
		message.font = .systemFont(ofSize: NSFont.systemFontSize)
		message.translatesAutoresizingMaskIntoConstraints = false
		message.isHidden = options.string("message").isEmpty
		message.lineBreakMode = .byWordWrapping
		message.maximumNumberOfLines = 0
		message.preferredMaxLayoutWidth = 440
		message.allowsEditingTextAttributes = true
		message.isSelectable = true
		if !message.isHidden {
			message.attributedStringValue = Markdown.attributed(
				options.string("message"),
				font: .systemFont(ofSize: NSFont.systemFontSize)
			)
		}

		controlView = NSView()
		controlView.translatesAutoresizingMaskIntoConstraints = false

		buttonsRow = NSStackView()
		buttonsRow.orientation = .horizontal
		buttonsRow.alignment = .centerY
		buttonsRow.spacing = 12
		buttonsRow.translatesAutoresizingMaskIntoConstraints = false

		// Build buttons from --buttons / --button1 / --button2 / --button3.
		var labels = options.array("buttons")
		let b1 = options.string("button1")
		let b2 = options.string("button2")
		let b3 = options.string("button3")
		if labels == ["OK"] && (!b1.isEmpty || !b2.isEmpty || !b3.isEmpty) {
			labels = [b1, b2, b3].filter { !$0.isEmpty }
		}
		makeButtons(labels: labels, options: options)

		// Compose contentView.
		let cv = panel.contentView!
		cv.addSubview(iconView)
		cv.addSubview(header)
		cv.addSubview(message)
		cv.addSubview(controlView)
		cv.addSubview(buttonsRow)

		let textLeading = iconView.isHidden ? cv.leadingAnchor : iconView.trailingAnchor
		let textLeadingPad: CGFloat = iconView.isHidden ? 20 : 16

		var constraints: [NSLayoutConstraint] = [
			header.leadingAnchor.constraint(equalTo: textLeading, constant: textLeadingPad),
			cv.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: 20),
			header.topAnchor.constraint(equalTo: cv.topAnchor, constant: 20),

			message.leadingAnchor.constraint(equalTo: textLeading, constant: textLeadingPad),
			cv.trailingAnchor.constraint(equalTo: message.trailingAnchor, constant: 20),
			message.topAnchor.constraint(equalTo: header.isHidden ? cv.topAnchor : header.bottomAnchor, constant: header.isHidden ? 20 : 8),

			controlView.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
			cv.trailingAnchor.constraint(equalTo: controlView.trailingAnchor, constant: 20),
			controlView.topAnchor.constraint(equalTo: anchorAboveControlView(), constant: spacingAboveControlView()),

			buttonsRow.topAnchor.constraint(greaterThanOrEqualTo: controlView.bottomAnchor, constant: 16),
			cv.trailingAnchor.constraint(equalTo: buttonsRow.trailingAnchor, constant: 20),
			cv.bottomAnchor.constraint(equalTo: buttonsRow.bottomAnchor, constant: 20),
		]
		if !iconView.isHidden {
			constraints += [
				iconView.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
				iconView.topAnchor.constraint(equalTo: cv.topAnchor, constant: 20),
				iconView.widthAnchor.constraint(equalToConstant: 48),
				iconView.heightAnchor.constraint(equalToConstant: 48),
			]
		}
		NSLayoutConstraint.activate(constraints)

		// Apply explicit width / height if given.
		var size = NSSize(width: 480, height: 200)
		let w = options.double("width")
		let h = options.double("height")
		if w > 0 { size.width = CGFloat(w) }
		if h > 0 { size.height = CGFloat(h) }
		panel.setContentSize(size)
		panel.center()

		// ESC -> cancel-button (or last button) click.
		installEscMonitor(options: options)
	}

	private func anchorAboveControlView() -> NSLayoutAnchor<NSLayoutYAxisAnchor> {
		if !message.isHidden { return message.bottomAnchor }
		if !header.isHidden  { return header.bottomAnchor }
		if !iconView.isHidden { return iconView.bottomAnchor }
		return panel.contentView!.topAnchor
	}

	private func spacingAboveControlView() -> CGFloat {
		(message.isHidden && header.isHidden && iconView.isHidden) ? 20 : 16
	}

	private func makeButtons(labels: [String], options: ParsedOptions) {
		let cancelTarget = options.string("cancel-button").lowercased()
		let defaultTarget = options.string("default-button").lowercased()
		for (i, label) in labels.enumerated() {
			let b = NSButton(title: label, target: self, action: #selector(buttonClicked(_:)))
			b.tag = i
			b.bezelStyle = .rounded
			b.translatesAutoresizingMaskIntoConstraints = false
			if !defaultTarget.isEmpty && label.lowercased() == defaultTarget {
				b.keyEquivalent = "\r"
			} else if defaultTarget.isEmpty && i == 0 {
				b.keyEquivalent = "\r"
			}
			if !cancelTarget.isEmpty && label.lowercased() == cancelTarget {
				b.keyEquivalent = "\u{1B}"
			}
			buttons.append(b)
		}
		for b in buttons.reversed() {
			buttonsRow.addArrangedSubview(b)
		}
	}

	private func installEscMonitor(options: ParsedOptions) {
		keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
			guard let self else { return event }
			if event.keyCode == 53, event.window === self.panel {
				let cancel = self.buttons.first(where: { $0.keyEquivalent == "\u{1B}" }) ?? self.buttons.last
				cancel?.performClick(nil)
				return nil
			}
			return event
		}
	}

	@objc private func buttonClicked(_ sender: NSButton) {
		clickedIndex = sender.tag
		NSApp.stopModal(withCode: NSApplication.ModalResponse(sender.tag))
	}

	private func startTimeout(_ seconds: Double, defaultButton: String) {
		let t = Timer(timeInterval: seconds, repeats: false) { [weak self] _ in
			guard let self else { return }
			let target = defaultButton.lowercased()
			let btn = self.buttons.first(where: { $0.title.lowercased() == target })
				?? self.buttons.first(where: { $0.keyEquivalent == "\r" })
				?? self.buttons.first
			btn?.performClick(nil)
		}
		RunLoop.main.add(t, forMode: .common)
		RunLoop.main.add(t, forMode: .modalPanel)
		timeoutTimer = t
	}

	/// Run modal, return the clicked button's tag (or nil if dismissed).
	func runModal() -> (index: Int?, label: String?) {
		if timeout > 0 {
			startTimeout(timeout, defaultButton: timeoutDefaultButton)
		}
		panel.makeKeyAndOrderFront(nil)
		NSApp.activate(ignoringOtherApps: true)
		let resp = NSApp.runModal(for: panel)
		timeoutTimer?.invalidate()
		timeoutTimer = nil
		if let monitor = keyMonitor {
			NSEvent.removeMonitor(monitor)
			keyMonitor = nil
		}
		panel.orderOut(nil)
		let idx = resp.rawValue
		guard idx >= 0 && idx < buttons.count else { return (nil, nil) }
		return (idx, buttons[idx].title)
	}
}
