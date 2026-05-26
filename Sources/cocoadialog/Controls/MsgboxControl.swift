import AppKit

final class MsgboxControl: Control {
	static var scope: String { "msgbox" }
	var optionDefinitions: [OptionDefinition] {
		// msgbox just uses common options.
		DialogOptions.common
	}

	func run(options: ParsedOptions) -> ControlResult {
		let dialog = DialogPanel(options: options)
		// msgbox has no extra control inside; keep controlView at zero height.
		dialog.controlView.heightAnchor.constraint(equalToConstant: 0).isActive = true
		let (index, label) = dialog.runModal()
		var r = ControlResult()
		r.buttonIndex = index
		r.buttonLabel = label
		// msgbox emits the button label only.
		if let label { r.values = [label] }
		if let idx = index, idx > 0 {
			r.exit = .cancel
		}
		return r
	}
}
