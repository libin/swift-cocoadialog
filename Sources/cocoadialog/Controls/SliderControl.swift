import AppKit

final class SliderControl: Control {
	static var scope: String { "slider" }
	var optionDefinitions: [OptionDefinition] {
		DialogOptions.common + [
			OptionDefinition(name: "min", kind: .number, defaultValue: "0", help: "Minimum value"),
			OptionDefinition(name: "max", kind: .number, defaultValue: "100", help: "Maximum value"),
			OptionDefinition(name: "value", kind: .number, help: "Initial value (default: min)"),
			OptionDefinition(name: "ticks", kind: .number, defaultValue: "11", help: "Number of tick marks (0 disables)"),
			OptionDefinition(name: "return-float", kind: .boolean, help: "Return %.2f instead of integer"),
			OptionDefinition(name: "slider-label", kind: .string, defaultValue: "Choose a value:", help: "Caption above the slider"),
		]
	}

	private var valueField: NSTextField!
	private var returnFloat = false

	func run(options: ParsedOptions) -> ControlResult {
		let dialog = DialogPanel(options: options)
		returnFloat = options.bool("return-float")

		let slider = NSSlider()
		slider.translatesAutoresizingMaskIntoConstraints = false
		slider.minValue = options.double("min", default: 0)
		slider.maxValue = options.double("max", default: 100)
		slider.doubleValue = options.wasProvided("value") ? options.double("value") : slider.minValue
		let ticks = options.int("ticks", default: 11)
		slider.numberOfTickMarks = ticks > 0 ? ticks : 0
		slider.allowsTickMarkValuesOnly = false

		let labelField = NSTextField(labelWithString: options.string("slider-label", default: "Choose a value:"))
		labelField.translatesAutoresizingMaskIntoConstraints = false

		valueField = NSTextField(labelWithString: format(slider.doubleValue))
		valueField.translatesAutoresizingMaskIntoConstraints = false
		valueField.alignment = .right

		slider.target = self
		slider.action = #selector(sliderChanged(_:))

		let labelRow = NSStackView(views: [labelField, valueField])
		labelRow.translatesAutoresizingMaskIntoConstraints = false
		labelRow.orientation = .horizontal
		labelRow.distribution = .fill
		labelField.setContentHuggingPriority(.defaultLow, for: .horizontal)
		valueField.setContentHuggingPriority(.required, for: .horizontal)

		let stack = NSStackView(views: [labelRow, slider])
		stack.translatesAutoresizingMaskIntoConstraints = false
		stack.orientation = .vertical
		stack.alignment = .leading
		stack.spacing = 4

		dialog.controlView.addSubview(stack)
		NSLayoutConstraint.activate([
			stack.leadingAnchor.constraint(equalTo: dialog.controlView.leadingAnchor),
			stack.trailingAnchor.constraint(equalTo: dialog.controlView.trailingAnchor),
			stack.topAnchor.constraint(equalTo: dialog.controlView.topAnchor),
			dialog.controlView.bottomAnchor.constraint(equalTo: stack.bottomAnchor),
			slider.widthAnchor.constraint(greaterThanOrEqualToConstant: 320),
			labelRow.widthAnchor.constraint(equalTo: slider.widthAnchor),
		])

		let (index, label) = dialog.runModal()
		var r = ControlResult()
		r.buttonIndex = index
		r.buttonLabel = label
		if let label { r.values.append(label) }
		r.values.append(format(slider.doubleValue))
		if let idx = index, idx > 0 {
			r.exit = .cancel
		}
		return r
	}

	@objc private func sliderChanged(_ sender: NSSlider) {
		valueField.stringValue = format(sender.doubleValue)
	}

	private func format(_ v: Double) -> String {
		returnFloat ? String(format: "%.2f", v) : String(Int(v.rounded()))
	}
}
