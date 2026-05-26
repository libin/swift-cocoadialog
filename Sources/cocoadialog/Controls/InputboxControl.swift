import AppKit

final class InputboxControl: Control {
	static var scope: String { "inputbox" }
	var optionDefinitions: [OptionDefinition] {
		DialogOptions.common + [
			OptionDefinition(name: "value", kind: .string, aliases: ["text"], help: "Pre-fill the input field"),
			OptionDefinition(name: "secure", kind: .boolean, aliases: ["no-show"], help: "Use a secure (password) field"),
			OptionDefinition(name: "selected", kind: .boolean, aliases: ["not-selected"], help: "Pre-select the value text"),
			OptionDefinition(name: "placeholder", kind: .string, help: "Placeholder text when field is empty"),
		]
	}

	func run(options: ParsedOptions) -> ControlResult {
		let dialog = DialogPanel(options: options)
		let initial = options.string("value")

		let field: NSTextField = options.bool("secure")
			? NSSecureTextField(string: initial)
			: NSTextField(string: initial)
		field.translatesAutoresizingMaskIntoConstraints = false
		field.placeholderString = options.string("placeholder")
		field.isEditable = true
		field.isSelectable = true

		dialog.controlView.addSubview(field)
		NSLayoutConstraint.activate([
			field.leadingAnchor.constraint(equalTo: dialog.controlView.leadingAnchor),
			field.trailingAnchor.constraint(equalTo: dialog.controlView.trailingAnchor),
			field.topAnchor.constraint(equalTo: dialog.controlView.topAnchor),
			field.heightAnchor.constraint(equalToConstant: 24),
			dialog.controlView.bottomAnchor.constraint(equalTo: field.bottomAnchor),
		])

		// Cocoa default: focus the field when shown.
		DispatchQueue.main.async {
			dialog.panel.makeFirstResponder(field)
			if options.bool("selected") {
				field.selectText(nil)
			}
		}

		let (index, label) = dialog.runModal()
		var r = ControlResult()
		r.buttonIndex = index
		r.buttonLabel = label
		// Output: button label, then field value.
		if let label { r.values.append(label) }
		r.values.append(field.stringValue)
		if let idx = index, idx > 0 {
			r.exit = .cancel
		}
		return r
	}
}
