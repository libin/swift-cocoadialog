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
			OptionDefinition(name: "recommended", kind: .string, help: "Index or label of the recommended option (pre-checked + (recommended) suffix in muted color)"),
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

		// Resolve --recommended: accept 0-based index or label match.
		let recommendedRaw = options.string("recommended")
		var recommendedIdx: Int = -1
		if !recommendedRaw.isEmpty {
			if let n = Int(recommendedRaw), n >= 0, n < items.count {
				recommendedIdx = n
			} else if let n = items.firstIndex(of: recommendedRaw) {
				recommendedIdx = n
			}
		}

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
			if i == recommendedIdx {
				// Append " (recommended)" in muted color; pre-check this option.
				let base = NSMutableAttributedString(
					string: label,
					attributes: [.foregroundColor: NSColor.labelColor]
				)
				base.append(NSAttributedString(
					string: " (recommended)",
					attributes: [.foregroundColor: NSColor.secondaryLabelColor]
				))
				b.attributedTitle = base
				b.state = .on
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
			// Disable input until the freeform radio is selected; typing
			// auto-selects the freeform radio for convenience.
			if kind == .radio, let rb = inputRadio {
				let enabled = (rb.state == .on)
				inputField?.isEnabled = enabled
				inputTextView?.isEditable = enabled
				// Sync enabled-state on radio toggle.
				objc_setAssociatedObject(self, &Self.inputFieldKey, inputField as Any, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
				objc_setAssociatedObject(self, &Self.inputTextViewKey, inputTextView as Any, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
				objc_setAssociatedObject(self, &Self.inputRadioKey, rb, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
				// Auto-select freeform radio when user types in the field.
				if let tf = inputField {
					NotificationCenter.default.addObserver(
						self,
						selector: #selector(inputDidChange(_:)),
						name: NSControl.textDidChangeNotification,
						object: tf
					)
				}
				if let tv = inputTextView {
					NotificationCenter.default.addObserver(
						self,
						selector: #selector(inputDidChange(_:)),
						name: NSText.didChangeNotification,
						object: tv
					)
				}
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
				// Emit the ORIGINAL item value, not b.title (which may include
				// the attributed (recommended) suffix or other rendering hints).
				let raw = (i < items.count) ? items[i] : b.title
				r.values.append(raw)
			}
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
	private static var inputFieldKey = 0
	private static var inputTextViewKey = 0
	private static var inputRadioKey = 0

	@objc private func radioToggled(_ sender: NSButton) {
		let buttons = objc_getAssociatedObject(self, &Self.buttonsKey) as? [NSButton] ?? []
		for b in buttons where b !== sender { b.state = .off }
		sender.state = .on
		syncInputEnabled(focus: true)
	}

	@objc private func inputDidChange(_ note: Notification) {
		let buttons = objc_getAssociatedObject(self, &Self.buttonsKey) as? [NSButton] ?? []
		let inputRadio = objc_getAssociatedObject(self, &Self.inputRadioKey) as? NSButton
		guard let rb = inputRadio else { return }
		let wasOn = rb.state == .on
		for b in buttons where b !== rb { b.state = .off }
		rb.state = .on
		// Only focus if we just transitioned from off to on; otherwise the user
		// is already typing and we'd reset the cursor / selection.
		syncInputEnabled(focus: !wasOn)
	}

	private func syncInputEnabled(focus: Bool) {
		let inputRadio = objc_getAssociatedObject(self, &Self.inputRadioKey) as? NSButton
		let enabled = inputRadio?.state == .on
		if let tf = objc_getAssociatedObject(self, &Self.inputFieldKey) as? NSTextField {
			tf.isEnabled = enabled
			if enabled && focus { tf.window?.makeFirstResponder(tf) }
		}
		if let tv = objc_getAssociatedObject(self, &Self.inputTextViewKey) as? NSTextView {
			tv.isEditable = enabled
			if enabled && focus { tv.window?.makeFirstResponder(tv) }
		}
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
