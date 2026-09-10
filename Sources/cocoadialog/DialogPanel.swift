import AppKit

/// Reusable layout: a vertical stack inside an opaque NSPanel.
/// - Optional icon on the left
/// - Header (bold) at top
/// - Message (regular) below header — supports inline markdown, or shell syntax
///   highlighting when the text looks like a command. Rendered in a
///   height-capped scroll view so long content (e.g. a `rm -rf …` command being
///   confirmed) scrolls instead of pushing the buttons off the screen.
/// - Custom controlView in the middle (filled by the concrete Control)
/// - Buttons row at bottom-right
final class DialogPanel {
	let panel: NSPanel
	let header: NSTextField
	let messageScroll: NSScrollView
	let messageView: NSTextView
	let hasMessage: Bool
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

		// Header.
		header = NSTextField(labelWithString: "")
		header.font = .boldSystemFont(ofSize: NSFont.systemFontSize + 2)
		header.translatesAutoresizingMaskIntoConstraints = false
		header.isHidden = options.string("header").isEmpty
		header.lineBreakMode = .byWordWrapping
		header.maximumNumberOfLines = 0
		header.preferredMaxLayoutWidth = 440
		header.allowsEditingTextAttributes = true
		header.isSelectable = true
		let headerRaw = options.string("header")
		if !header.isHidden {
			if ShellHighlighter.looksLikeCommand(headerRaw) {
				header.attributedStringValue = ShellHighlighter.attributed(
					headerRaw,
					font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize + 1, weight: .semibold)
				)
			} else {
				header.attributedStringValue = Markdown.attributed(
					headerRaw,
					font: .boldSystemFont(ofSize: NSFont.systemFontSize + 2)
				)
			}
		}

		// Message body — rendered in a height-capped scroll view so long content
		// scrolls and the buttons never leave the screen. Shell-like content is
		// syntax highlighted; everything else uses the inline-markdown renderer.
		let messageRaw = options.string("message")
		hasMessage = !messageRaw.isEmpty
		messageView = NSTextView()
		messageScroll = NSScrollView()
		let messageIsCommand = hasMessage && ShellHighlighter.looksLikeCommand(messageRaw)
		let msgFont: NSFont = messageIsCommand
			? NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
			: NSFont.systemFont(ofSize: NSFont.systemFontSize)
		if hasMessage {
			messageView.isEditable = false
			messageView.isSelectable = true
			messageView.drawsBackground = false
			messageView.textContainerInset = NSSize(width: 0, height: 2)
			messageView.isVerticallyResizable = true
			messageView.isHorizontallyResizable = false
			messageView.autoresizingMask = .width
			messageView.minSize = NSSize(width: 0, height: 0)
			messageView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
			messageView.textContainer?.widthTracksTextView = true
			messageView.textContainer?.lineFragmentPadding = 0
			let attr = messageIsCommand
				? ShellHighlighter.attributed(messageRaw, font: msgFont)
				: Markdown.attributed(messageRaw, font: msgFont)
			messageView.textStorage?.setAttributedString(attr)

			messageScroll.translatesAutoresizingMaskIntoConstraints = false
			messageScroll.hasVerticalScroller = true
			messageScroll.hasHorizontalScroller = false
			messageScroll.drawsBackground = false
			messageScroll.borderType = .noBorder
			messageScroll.autohidesScrollers = true
			// Always show a real scrollbar (not the fading overlay) when the body
			// overflows, so it is obvious there is more command below the fold.
			messageScroll.scrollerStyle = .legacy
			messageScroll.documentView = messageView
		}
		messageScroll.isHidden = !hasMessage

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
		if hasMessage { cv.addSubview(messageScroll) }
		cv.addSubview(controlView)
		cv.addSubview(buttonsRow)

		let textLeading = iconView.isHidden ? cv.leadingAnchor : iconView.trailingAnchor
		let textLeadingPad: CGFloat = iconView.isHidden ? 20 : 16

		// Determine content width up-front (auto-grow to fit the longest header /
		// message line, capped to 70% of the screen) so we can measure the wrapped
		// message height before laying out.
		let screen = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1440, height: 900)
		let boldFont = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize + 2)
		let longestHeader = ceil(longestLineWidth(headerRaw, font: boldFont))
		let longestMsg = ceil(longestLineWidth(messageRaw, font: msgFont))
		var width = min(max(480, max(longestHeader, longestMsg) + 80), screen.width * 0.70)
		if let w = parseSize(options.string("width"), screen: screen.width), w > 0 { width = w }

		// Measure the message height at the resolved width and cap the scroll view
		// so very long commands scroll instead of growing the window off-screen.
		let sidePad: CGFloat = textLeadingPad + 20 + (iconView.isHidden ? 0 : 64)
		let textWidth = max(120, width - sidePad)
		let maxMsgH = max(120, screen.height * 0.5)
		if hasMessage {
			let measured = messageView.attributedString().boundingRect(
				with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
				options: [.usesLineFragmentOrigin, .usesFontLeading]
			).height
			// Cap the body at ~half the screen; taller content scrolls inside so the
			// buttons below never leave the screen.
			let msgH = min(ceil(measured) + 8, maxMsgH)
			messageScroll.heightAnchor.constraint(equalToConstant: msgH).isActive = true
		}

		var constraints: [NSLayoutConstraint] = [
			header.leadingAnchor.constraint(equalTo: textLeading, constant: textLeadingPad),
			cv.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: 20),
			header.topAnchor.constraint(equalTo: cv.topAnchor, constant: 20),

			controlView.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
			cv.trailingAnchor.constraint(equalTo: controlView.trailingAnchor, constant: 20),
			controlView.topAnchor.constraint(equalTo: anchorAboveControlView(), constant: spacingAboveControlView()),

			buttonsRow.topAnchor.constraint(greaterThanOrEqualTo: controlView.bottomAnchor, constant: 16),
			cv.trailingAnchor.constraint(equalTo: buttonsRow.trailingAnchor, constant: 20),
			cv.bottomAnchor.constraint(equalTo: buttonsRow.bottomAnchor, constant: 20),

			// Keep the content at least the computed width so the window never
			// collapses to its content's fitting size (e.g. a short radio menu with no
			// --message). Height stays constraint-driven (bounded by the capped body).
			cv.widthAnchor.constraint(greaterThanOrEqualToConstant: width),
			// Hard ceiling: no control (e.g. a dropdown holding a very long web page
			// title) may widen the window past the screen, which would push the
			// buttons out of view. Controls must compress/truncate instead.
			cv.widthAnchor.constraint(lessThanOrEqualToConstant: max(width, screen.width * 0.85)),
		]
		if hasMessage {
			constraints += [
				messageScroll.leadingAnchor.constraint(equalTo: textLeading, constant: textLeadingPad),
				cv.trailingAnchor.constraint(equalTo: messageScroll.trailingAnchor, constant: 20),
				messageScroll.topAnchor.constraint(
					equalTo: header.isHidden ? cv.topAnchor : header.bottomAnchor,
					constant: header.isHidden ? 20 : 8
				),
			]
		}
		if !iconView.isHidden {
			constraints += [
				iconView.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 20),
				iconView.topAnchor.constraint(equalTo: cv.topAnchor, constant: 20),
				iconView.widthAnchor.constraint(equalToConstant: 48),
				iconView.heightAnchor.constraint(equalToConstant: 48),
			]
		}
		NSLayoutConstraint.activate(constraints)

		// Apply width; the window height is constraint-driven and grows to fit
		// header + (capped) message + control + buttons. Because the message body is
		// capped at ~half the screen, the total never pushes the buttons off-screen.
		var height = 200.0
		if let h = parseSize(options.string("height"), screen: screen.height), h > 0 { height = h }
		header.preferredMaxLayoutWidth = width - 80
		panel.setContentSize(NSSize(width: width, height: height))
		panel.center()

		// ESC -> cancel-button (or last button) click.
		installEscMonitor(options: options)
	}

	/// Expand the content width to comfortably fit a control (e.g. a long list
	/// of choices), capped to a fraction of the screen so the window never
	/// becomes an ultra-wide thin strip. Height stays constraint-driven and the
	/// call is a no-op if the panel is already at least this wide.
	func expandContentWidth(to target: CGFloat) {
		let screenW = NSScreen.main?.visibleFrame.width ?? 1440
		let want = min(target, screenW * 0.85)
		let cur = panel.contentRect(forFrameRect: panel.frame).size
		guard want > cur.width else { return }
		header.preferredMaxLayoutWidth = want - 80
		panel.setContentSize(NSSize(width: want, height: cur.height))
		panel.center()
	}

	private func parseSize(_ raw: String, screen: CGFloat) -> CGFloat? {
		let s = raw.trimmingCharacters(in: .whitespaces)
		if s.isEmpty { return nil }
		if s.hasSuffix("%") {
			let n = Double(s.dropLast()) ?? 0
			return CGFloat(n / 100.0) * screen
		}
		return (Double(s) ?? 0) > 0 ? CGFloat(Double(s)!) : nil
	}

	private func longestLineWidth(_ s: String, font: NSFont) -> CGFloat {
		guard !s.isEmpty else { return 0 }
		let attrs: [NSAttributedString.Key: Any] = [.font: font]
		return s.split(separator: "\n").map { line -> CGFloat in
			(String(line) as NSString).size(withAttributes: attrs).width
		}.max() ?? 0
	}

	private func anchorAboveControlView() -> NSLayoutAnchor<NSLayoutYAxisAnchor> {
		if hasMessage { return messageScroll.bottomAnchor }
		if !header.isHidden { return header.bottomAnchor }
		if !iconView.isHidden { return iconView.bottomAnchor }
		return panel.contentView!.topAnchor
	}

	private func spacingAboveControlView() -> CGFloat {
		(!hasMessage && header.isHidden && iconView.isHidden) ? 20 : 16
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
