import AppKit

/// A view whose coordinate origin is top-left, like UIKit / flipped NSTextView.
/// Used as the `documentView` holder for the options scroll view: a plain NSView
/// has a bottom-left origin, which makes the scroll view open scrolled to the
/// BOTTOM of a long list (first item hidden above the fold).
final class FlippedView: NSView {
	override var isFlipped: Bool { true }
}

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
		stack.spacing = 10
		stack.translatesAutoresizingMaskIntoConstraints = false

		// Long choice labels should wrap to multiple lines instead of forcing an
		// ultra-wide, thin window. Make each button full-width and word-wrapping.
		func makeWrapping(_ b: NSButton) {
			b.lineBreakMode = .byWordWrapping
			b.cell?.usesSingleLineMode = false
			(b.cell as? NSButtonCell)?.wraps = true
			// Prefer wrapping over widening the window: without this the button
			// insists on its full single-line width and stretches the dialog into a
			// thin strip.
			b.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
			// ...but NEVER compress vertically. The options live in a height-capped
			// scroll view; without a required vertical resistance AppKit satisfies the
			// cap by squashing the buttons into each other (overlapping text) instead
			// of letting the content overflow and scroll.
			b.setContentCompressionResistancePriority(.required, for: .vertical)
			b.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
		}

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
				let para = NSMutableParagraphStyle()
				para.lineBreakMode = .byWordWrapping
				base.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: base.length))
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
			makeWrapping(b)
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
				makeWrapping(rb)
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

		// Host the options in a height-capped scroll view: a long list (e.g. 20+
		// browser tabs) then scrolls instead of growing the window until the buttons
		// fall off the bottom of the screen. Short lists render at natural height
		// with no scroller.
		let screenH = NSScreen.main?.visibleFrame.height ?? 900
		let maxStackH = max(160, screenH * 0.5)

		let optionsScroll = NSScrollView()
		optionsScroll.translatesAutoresizingMaskIntoConstraints = false
		optionsScroll.hasVerticalScroller = true
		optionsScroll.hasHorizontalScroller = false
		optionsScroll.drawsBackground = false
		optionsScroll.borderType = .noBorder
		optionsScroll.autohidesScrollers = true
		optionsScroll.scrollerStyle = .legacy

		let holder = FlippedView()
		holder.translatesAutoresizingMaskIntoConstraints = false
		holder.addSubview(stack)
		optionsScroll.documentView = holder

		dialog.controlView.addSubview(optionsScroll)
		NSLayoutConstraint.activate([
			stack.leadingAnchor.constraint(equalTo: holder.leadingAnchor),
			stack.trailingAnchor.constraint(equalTo: holder.trailingAnchor),
			stack.topAnchor.constraint(equalTo: holder.topAnchor),
			holder.bottomAnchor.constraint(equalTo: stack.bottomAnchor),
			// Match the clip view's width so options wrap to the dialog width instead
			// of scrolling horizontally.
			holder.widthAnchor.constraint(equalTo: optionsScroll.contentView.widthAnchor),

			optionsScroll.leadingAnchor.constraint(equalTo: dialog.controlView.leadingAnchor),
			optionsScroll.trailingAnchor.constraint(equalTo: dialog.controlView.trailingAnchor),
			optionsScroll.topAnchor.constraint(equalTo: dialog.controlView.topAnchor),
			dialog.controlView.bottomAnchor.constraint(equalTo: optionsScroll.bottomAnchor),
			optionsScroll.heightAnchor.constraint(lessThanOrEqualToConstant: maxStackH),
		])
		// Hug the natural (unscrolled) height so a short list renders at full height
		// with no scroller. For a long list this loses to the required cap and
		// breaks, leaving scroll.height = cap while the holder keeps its full
		// natural height — i.e. the excess scrolls. That only works because the
		// buttons resist vertical compression at .required (see makeWrapping):
		// otherwise AppKit satisfies the cap by squashing them into each other.
		let hug = optionsScroll.heightAnchor.constraint(equalTo: holder.heightAnchor)
		hug.priority = .defaultHigh
		hug.isActive = true

		objc_setAssociatedObject(self, &Self.buttonsKey, buttons, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

		// Pick a comfortable width: wide enough to read the longest option, but
		// capped so a long option wraps to a couple of lines rather than producing
		// an ultra-wide, thin window. Short option lists stay compact.
		let optFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
		let longestOpt = (items + (hasInput ? [inputLabel] : [])).map {
			($0 as NSString).size(withAttributes: [.font: optFont]).width
		}.max() ?? 0
		// + ~110pt: radio glyph + leading/trailing window padding + breathing room.
		let desiredWidth = min(max(longestOpt + 110, 460), 640)
		dialog.expandContentWidth(to: desiredWidth)

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
