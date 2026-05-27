import AppKit

/// Shared helper for radio + checkbox controls. cocoadialog's CDMatrix
/// builds an NSMatrix; we use a vertical NSStackView of NSButtons since
/// NSMatrix is deprecated and brittle on macOS 14+.
final class ChoiceControl: Control {
	enum Kind { case radio, checkbox }

	static var scope: String { "" }  // overridden per-kind below
	let kind: Kind

	init(kind: Kind) { self.kind = kind }

	var optionDefinitions: [OptionDefinition] {
		DialogOptions.common + [
			OptionDefinition(name: "items", kind: .stringArray, maxValues: -1, help: "Choice labels"),
			OptionDefinition(name: "checked", kind: .stringArray, maxValues: -1, help: "Initially checked indices (0-based) or labels"),
			OptionDefinition(name: "disabled", kind: .stringArray, maxValues: -1, help: "Disabled indices or labels"),
			OptionDefinition(name: "rows", kind: .number, help: "Force layout rows (default: auto)"),
			OptionDefinition(name: "columns", kind: .number, help: "Force layout columns (default: 1)"),
		]
	}

	func run(options: ParsedOptions) -> ControlResult {
		let dialog = DialogPanel(options: options)
		let items = options.array("items")
		let initiallyChecked = Set(options.array("checked"))
		let disabled = Set(options.array("disabled"))

		let stack = NSStackView()
		stack.orientation = .vertical
		stack.alignment = .leading
		stack.spacing = 4
		stack.translatesAutoresizingMaskIntoConstraints = false

		var buttons: [NSButton] = []
		for (i, label) in items.enumerated() {
			let b: NSButton
			if kind == .radio {
				b = NSButton(radioButtonWithTitle: label, target: nil, action: nil)
			} else {
				b = NSButton(checkboxWithTitle: label, target: nil, action: nil)
			}
			let key = String(i)
			if initiallyChecked.contains(key) || initiallyChecked.contains(label) {
				b.state = .on
			}
			if disabled.contains(key) || disabled.contains(label) {
				b.isEnabled = false
			}
			if kind == .radio {
				// Radio buttons need a shared action target so only one is on.
				b.action = #selector(radioToggled(_:))
				b.target = self
			}
			buttons.append(b)
			stack.addArrangedSubview(b)
		}

		// Default to first radio if nothing pre-selected.
		if kind == .radio && !buttons.contains(where: { $0.state == .on }) {
			buttons.first?.state = .on
		}

		dialog.controlView.addSubview(stack)
		NSLayoutConstraint.activate([
			stack.leadingAnchor.constraint(equalTo: dialog.controlView.leadingAnchor),
			stack.trailingAnchor.constraint(lessThanOrEqualTo: dialog.controlView.trailingAnchor),
			stack.topAnchor.constraint(equalTo: dialog.controlView.topAnchor),
			dialog.controlView.bottomAnchor.constraint(equalTo: stack.bottomAnchor),
		])

		// Stash for radio toggle handler.
		objc_setAssociatedObject(self, &Self.buttonsKey, buttons, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

		let (index, label) = dialog.runModal()
		var r = ControlResult()
		r.buttonIndex = index
		r.buttonLabel = label
		if let label { r.values.append(label) }
		// Emit selected items (one per line for checkbox; single for radio).
		for b in buttons where b.state == .on {
			r.values.append(b.title)
		}
		if let idx = index, idx > 0 {
			r.exit = .cancel
		}
		return r
	}

	private static var buttonsKey = 0

	@objc private func radioToggled(_ sender: NSButton) {
		let buttons = objc_getAssociatedObject(self, &Self.buttonsKey) as? [NSButton] ?? []
		for b in buttons where b !== sender { b.state = .off }
		sender.state = .on
	}
}

final class RadioControl: Control {
	static var scope: String { "radio" }
	private let inner = ChoiceControl(kind: .radio)
	var optionDefinitions: [OptionDefinition] { inner.optionDefinitions }
	func run(options: ParsedOptions) -> ControlResult { inner.run(options: options) }
}

final class CheckboxControl: Control {
	static var scope: String { "checkbox" }
	private let inner = ChoiceControl(kind: .checkbox)
	var optionDefinitions: [OptionDefinition] { inner.optionDefinitions }
	func run(options: ParsedOptions) -> ControlResult { inner.run(options: options) }
}
