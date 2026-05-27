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
			OptionDefinition(name: "with-input", kind: .string, help: "Append an inline freeform input row with this label (single-line)"),
			OptionDefinition(name: "with-input-multiline", kind: .boolean, help: "Render --with-input as a multi-line text box instead of a single-line input"),
			OptionDefinition(name: "input-placeholder", kind: .string, help: "Placeholder for the inline input (when --with-input)"),
		]
	}

	func run(options: ParsedOptions) -> ControlResult {
		let dialog = DialogPanel(options: options)
		let items = options.array("items")
		let initiallyChecked = Set(options.array("checked"))
		let disabled = Set(options.array("disabled"))
		let inputLabel = options.string("with-input")
		let hasInput = !inputLabel.isEmpty
		let inputMultiline = options.bool("with-input-multiline")
		let placeholder = options.string("input-placeholder")

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
				b.action = #selector(radioToggled(_:))
				b.target = self
			}
			buttons.append(b)
			stack.addArrangedSubview(b)
		}

		// Inline input row + radio button (radio mode only).
		var inputField: NSTextField? = nil
		var inputView: NSView? = nil
		var inputTextView: NSTextView? = nil
		var inputRadio: NSButton? = nil
		if hasInput {
			if kind == .radio {
				let rb = NSButton(radioButtonWithTitle: inputLabel, target: self, action: #selector(radioToggled(_:)))
				buttons.append(rb)
				stack.addArrangedSubview(rb)
				inputRadio = rb
			}
			if inputMultiline {
				let scroll = NSScrollView()
				scroll.translatesAutoresizingMaskIntoConstraints = false
				scroll.hasVerticalScroller = true
				scroll.borderType = .bezelBorder
				let tv = NSTextView()
				tv.isEditable = true
				tv.isRichText = false
				tv.font = .systemFont(ofSize: NSFont.systemFontSize)
				tv.textContainerInset = NSSize(width: 6, height: 6)
				tv.minSize = NSSize(width: 0, height: 0)
				tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
				tv.isVerticallyResizable = true
				tv.autoresizingMask = .width
				scroll.documentView = tv
				scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 90).isActive = true
				inputView = scroll
				inputTextView = tv
				stack.addArrangedSubview(scroll)
			} else {
				let tf = NSTextField()
				tf.translatesAutoresizingMaskIntoConstraints = false
				tf.placeholderString = placeholder.isEmpty ? inputLabel : placeholder
				tf.bezelStyle = .roundedBezel
				inputView = tf
				inputField = tf
				stack.addArrangedSubview(tf)
			}
			if let v = inputView {
				v.widthAnchor.constraint(greaterThanOrEqualToConstant: 360).isActive = true
			}
		}

		// Default to first radio if nothing pre-selected.
		if kind == .radio && !buttons.contains(where: { $0.state == .on }) {
			buttons.first?.state = .on
		}

		dialog.controlView.addSubview(stack)
		NSLayoutConstraint.activate([
			stack.leadingAnchor.constraint(equalTo: dialog.controlView.leadingAnchor),
			stack.trailingAnchor.constraint(equalTo: dialog.controlView.trailingAnchor),
			stack.topAnchor.constraint(equalTo: dialog.controlView.topAnchor),
			dialog.controlView.bottomAnchor.constraint(equalTo: stack.bottomAnchor),
		])

		objc_setAssociatedObject(self, &Self.buttonsKey, buttons, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

		let (index, label) = dialog.runModal()
		var r = ControlResult()
		r.buttonIndex = index
		r.buttonLabel = label
		if let label { r.values.append(label) }

		// Emit one selected radio's label (or all checked checkboxes), then
		// the freeform text if --with-input was set.
		let inputText: String = {
			if let f = inputField { return f.stringValue }
			if let tv = inputTextView { return tv.string }
			return ""
		}()
		for (i, b) in buttons.enumerated() where b.state == .on {
			// In radio mode, when the inline-input radio is the selected one,
			// emit the typed text instead of the radio label.
			if kind == .radio, hasInput, b === inputRadio {
				r.values.append(inputText)
			} else {
				r.values.append(b.title)
			}
			_ = i
		}
		// Checkbox: also append input text on its own line if non-empty.
		if kind == .checkbox, hasInput, !inputText.isEmpty {
			r.values.append(inputText)
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
