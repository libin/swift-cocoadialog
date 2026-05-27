import AppKit

final class AboutControl: Control {
	static var scope: String { "about" }
	var optionDefinitions: [OptionDefinition] {
		// About has no real options beyond standard --buttons.
		DialogOptions.common
	}

	func run(options: ParsedOptions) -> ControlResult {
		// Use a native NSAlert for the About dialog so it always renders
		// correctly regardless of panel layout state.
		NSApp.activate(ignoringOtherApps: true)
		let alert = NSAlert()
		alert.alertStyle = .informational
		alert.messageText = "swift-cocoadialog"
		let version = "3.0.0-swift"
		alert.informativeText = """
			Version \(version)
			Compatible reimplementation of cocoadialog 3.0 in Swift.
			MIT licensed. Not affiliated with the original cocoadialog project.

			https://github.com/cocoadialog/cocoadialog (original, GPL v2)
			"""
		// Honor --buttons if provided, else just OK.
		let buttons = options.array("buttons")
		let labels = buttons.isEmpty ? ["OK"] : buttons
		for label in labels { alert.addButton(withTitle: label) }
		let resp = alert.runModal()
		var r = ControlResult()
		let idx = resp.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
		r.buttonIndex = idx
		if idx >= 0 && idx < labels.count {
			r.buttonLabel = labels[idx]
			r.values = [labels[idx]]
		}
		if idx > 0 { r.exit = .cancel }
		return r
	}
}
