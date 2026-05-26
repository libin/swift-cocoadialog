import AppKit

final class TextboxControl: Control {
	static var scope: String { "textbox" }
	var optionDefinitions: [OptionDefinition] {
		DialogOptions.common + [
			OptionDefinition(name: "value", kind: .string, aliases: ["text"], help: "Pre-fill the textarea"),
			OptionDefinition(name: "file", kind: .string, aliases: ["text-from-file"], help: "Pre-fill from a file"),
			OptionDefinition(name: "editable", kind: .boolean, defaultValue: "YES", aliases: ["no-editable"], help: "Allow editing"),
			OptionDefinition(name: "focus", kind: .boolean, aliases: ["focus-textbox"], help: "Focus textarea on launch"),
			OptionDefinition(name: "selected", kind: .boolean, help: "Pre-select all text"),
			OptionDefinition(name: "scroll-to", kind: .string, defaultValue: "top", help: "top | bottom"),
		]
	}

	func run(options: ParsedOptions) -> ControlResult {
		let dialog = DialogPanel(options: options)

		// Build a scrollable text view.
		let scroll = NSScrollView()
		scroll.translatesAutoresizingMaskIntoConstraints = false
		scroll.hasVerticalScroller = true
		scroll.hasHorizontalScroller = false
		scroll.borderType = .bezelBorder
		scroll.autohidesScrollers = true

		let tv = NSTextView()
		tv.isEditable = options.bool("editable", default: true)
		tv.isSelectable = true
		tv.isRichText = false
		tv.allowsUndo = true
		tv.font = .systemFont(ofSize: NSFont.systemFontSize)
		tv.textContainerInset = NSSize(width: 8, height: 8)
		tv.minSize = NSSize(width: 0, height: 0)
		tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
		tv.isVerticallyResizable = true
		tv.isHorizontallyResizable = false
		tv.autoresizingMask = .width
		tv.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
		tv.textContainer?.widthTracksTextView = true

		var initial = options.string("value")
		if initial.isEmpty {
			let path = options.string("file")
			if !path.isEmpty, let body = try? String(contentsOfFile: path, encoding: .utf8) {
				initial = body
			}
		}
		if !initial.isEmpty {
			tv.string = initial
		}
		if options.bool("selected") {
			tv.setSelectedRange(NSRange(location: 0, length: tv.string.count))
		}

		scroll.documentView = tv

		dialog.controlView.addSubview(scroll)
		NSLayoutConstraint.activate([
			scroll.leadingAnchor.constraint(equalTo: dialog.controlView.leadingAnchor, constant: 10),
			scroll.trailingAnchor.constraint(equalTo: dialog.controlView.trailingAnchor, constant: -10),
			scroll.topAnchor.constraint(equalTo: dialog.controlView.topAnchor),
			scroll.bottomAnchor.constraint(equalTo: dialog.controlView.bottomAnchor),
			scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
			scroll.widthAnchor.constraint(greaterThanOrEqualToConstant: 380),
		])

		// ⌘⏎ to submit (click default button).
		let submitMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak panel = dialog.panel, buttons = dialog.buttons] event in
			guard event.window === panel else { return event }
			let isReturn = event.keyCode == 36 || event.keyCode == 76
			let cmdHeld = event.modifierFlags.contains(.command)
			if isReturn && cmdHeld {
				let def = buttons.first(where: { $0.keyEquivalent == "\r" }) ?? buttons.first
				def?.performClick(nil)
				return nil
			}
			return event
		}

		DispatchQueue.main.async {
			if options.bool("focus", default: true) {
				dialog.panel.makeFirstResponder(tv)
			}
		}

		let (index, label) = dialog.runModal()
		if let m = submitMonitor { NSEvent.removeMonitor(m) }

		var r = ControlResult()
		r.buttonIndex = index
		r.buttonLabel = label
		if let label { r.values.append(label) }
		r.values.append(tv.string)
		if let idx = index, idx > 0 {
			r.exit = .cancel
		}
		return r
	}
}
