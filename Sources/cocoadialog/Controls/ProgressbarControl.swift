import AppKit

final class ProgressbarControl: Control {
	static var scope: String { "progressbar" }
	var optionDefinitions: [OptionDefinition] {
		// Progressbar has no buttons by default; it closes on stdin EOF.
		// Filter out --buttons defaults from common (cocoadialog removes
		// button1/2/3 for progressbar; we just hide buttonsRow if no
		// buttons are explicitly requested).
		DialogOptions.common + [
			OptionDefinition(name: "percent", kind: .number, defaultValue: "0", help: "Initial percent (0-100)"),
			OptionDefinition(name: "indeterminate", kind: .boolean, help: "Indeterminate (spinner) mode"),
			OptionDefinition(name: "stoppable", kind: .boolean, help: "Show a Stop button"),
			OptionDefinition(name: "labels", kind: .stringArray, maxValues: 2, help: "Primary [secondary] label"),
		]
	}

	private weak var bar: NSProgressIndicator?
	private weak var primaryLabel: NSTextField?
	private weak var dialogPanel: DialogPanel?

	func run(options: ParsedOptions) -> ControlResult {
		let dialog = DialogPanel(options: options)
		dialogPanel = dialog
		// Hide buttons row for progressbar (unless --stoppable explicitly added).
		if !options.bool("stoppable") {
			dialog.buttonsRow.isHidden = true
		}

		let label = NSTextField(labelWithString: options.array("labels").first ?? "")
		label.translatesAutoresizingMaskIntoConstraints = false
		primaryLabel = label

		let bar = NSProgressIndicator()
		bar.translatesAutoresizingMaskIntoConstraints = false
		bar.style = .bar
		bar.minValue = 0
		bar.maxValue = 100
		bar.isIndeterminate = options.bool("indeterminate")
		bar.doubleValue = options.double("percent")
		if bar.isIndeterminate { bar.startAnimation(nil) }
		self.bar = bar

		let stack = NSStackView(views: [label, bar])
		stack.translatesAutoresizingMaskIntoConstraints = false
		stack.orientation = .vertical
		stack.alignment = .leading
		stack.spacing = 6

		dialog.controlView.addSubview(stack)
		NSLayoutConstraint.activate([
			stack.leadingAnchor.constraint(equalTo: dialog.controlView.leadingAnchor),
			stack.trailingAnchor.constraint(equalTo: dialog.controlView.trailingAnchor),
			stack.topAnchor.constraint(equalTo: dialog.controlView.topAnchor),
			dialog.controlView.bottomAnchor.constraint(equalTo: stack.bottomAnchor),
			bar.widthAnchor.constraint(greaterThanOrEqualToConstant: 360),
		])

		// Read stdin asynchronously.
		startStdinReader()

		// Run modal until stdin EOF (which calls stop).
		dialog.panel.makeKeyAndOrderFront(nil)
		NSApp.activate(ignoringOtherApps: true)
		_ = NSApp.runModal(for: dialog.panel)
		dialog.panel.orderOut(nil)

		var r = ControlResult()
		r.exit = .ok
		return r
	}

	private func startStdinReader() {
		let fh = FileHandle.standardInput
		fh.readabilityHandler = { [weak self] handle in
			let data = handle.availableData
			if data.isEmpty {
				// EOF.
				DispatchQueue.main.async { [weak self] in
					self?.stop()
				}
				handle.readabilityHandler = nil
				return
			}
			guard let text = String(data: data, encoding: .utf8) else { return }
			let lines = text.split(whereSeparator: \.isNewline)
			for line in lines {
				DispatchQueue.main.async { [weak self] in
					self?.handleLine(String(line))
				}
			}
		}
	}

	private func handleLine(_ line: String) {
		// Format: "<percent> <label?>"
		let trimmed = line.trimmingCharacters(in: .whitespaces)
		if trimmed.isEmpty { return }
		let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
		if let p = Double(parts[0]), let bar = bar {
			if !bar.isIndeterminate {
				bar.doubleValue = max(0, min(100, p))
				bar.needsDisplay = true
			}
		}
		if parts.count > 1 {
			primaryLabel?.stringValue = String(parts[1])
		}
	}

	private func stop() {
		bar?.stopAnimation(nil)
		NSApp.stopModal(withCode: .OK)
	}
}
