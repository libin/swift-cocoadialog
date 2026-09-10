import AppKit

final class DropdownControl: Control {
	static var scope: String { "dropdown" }
	var optionDefinitions: [OptionDefinition] {
		DialogOptions.common + [
			OptionDefinition(name: "items", kind: .stringArray, maxValues: -1, help: "Menu items"),
			OptionDefinition(name: "selected", kind: .number, help: "Index of initially selected item (0-based)"),
			OptionDefinition(name: "pulldown", kind: .boolean, help: "Render as a pull-down menu"),
		]
	}

	func run(options: ParsedOptions) -> ControlResult {
		let dialog = DialogPanel(options: options)

		let popup = NSPopUpButton(frame: .zero, pullsDown: options.bool("pulldown"))
		popup.translatesAutoresizingMaskIntoConstraints = false
		// A long item (e.g. a web page title) must not widen the window past the
		// screen and push the buttons out of view: let the popup be compressed and
		// ellipsize its title instead of insisting on its full intrinsic width.
		popup.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		popup.cell?.lineBreakMode = .byTruncatingTail
		popup.cell?.usesSingleLineMode = true
		let items = options.array("items")
		for item in items { popup.addItem(withTitle: item) }
		let initial = options.int("selected", default: 0)
		if initial >= 0 && initial < popup.numberOfItems {
			popup.selectItem(at: initial)
		}

		dialog.controlView.addSubview(popup)
		let screenW = NSScreen.main?.visibleFrame.width ?? 1440
		NSLayoutConstraint.activate([
			popup.leadingAnchor.constraint(equalTo: dialog.controlView.leadingAnchor),
			popup.trailingAnchor.constraint(equalTo: dialog.controlView.trailingAnchor),
			popup.topAnchor.constraint(equalTo: dialog.controlView.topAnchor),
			popup.heightAnchor.constraint(greaterThanOrEqualToConstant: 24),
			popup.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
			popup.widthAnchor.constraint(lessThanOrEqualToConstant: max(300, screenW * 0.8)),
			dialog.controlView.bottomAnchor.constraint(equalTo: popup.bottomAnchor),
		])

		let (index, label) = dialog.runModal()
		var r = ControlResult()
		r.buttonIndex = index
		r.buttonLabel = label
		if let label { r.values.append(label) }
		// Return both selected index and selected title (cocoadialog convention).
		r.values.append(String(popup.indexOfSelectedItem))
		r.values.append(popup.titleOfSelectedItem ?? "")
		if let idx = index, idx > 0 {
			r.exit = .cancel
		}
		return r
	}
}
