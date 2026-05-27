import AppKit

/// Wrapper around NSOpenPanel and NSSavePanel.
final class FilePickerControl: Control {
	enum Mode { case open, save }

	let mode: Mode
	init(mode: Mode) { self.mode = mode }

	static var scope: String { "" }  // overridden via subclasses below

	var optionDefinitions: [OptionDefinition] {
		var defs = DialogOptions.common + [
			OptionDefinition(name: "with-directory", kind: .string, help: "Initial directory"),
			OptionDefinition(name: "with-file",      kind: .string, help: "Initial filename"),
			OptionDefinition(name: "extensions",     kind: .stringArray, maxValues: -1, help: "Allowed extensions (without dot)"),
			OptionDefinition(name: "no-extension-hide", kind: .boolean, help: "Show all files regardless of extensions"),
		]
		if mode == .open {
			defs += [
				OptionDefinition(name: "select-multiple", kind: .boolean, aliases: ["no-select-multiple"], help: "Allow multiple selection"),
				OptionDefinition(name: "select-directories", kind: .boolean, defaultValue: "YES", aliases: ["no-select-directories"], help: "Allow choosing directories"),
				OptionDefinition(name: "select-only-directories", kind: .boolean, help: "Only directories may be chosen"),
			]
		}
		if mode == .save {
			defs += [
				OptionDefinition(name: "create-directories", kind: .boolean, defaultValue: "YES", help: "Allow user to create new directories"),
			]
		}
		return defs
	}

	func run(options: ParsedOptions) -> ControlResult {
		// Activate so the system panel comes to front.
		NSApp.setActivationPolicy(.regular)
		NSApp.activate(ignoringOtherApps: true)

		let panel: NSSavePanel
		if mode == .open {
			let op = NSOpenPanel()
			op.allowsMultipleSelection = options.bool("select-multiple")
			op.canChooseDirectories = options.bool("select-directories", default: true)
			if options.bool("select-only-directories") {
				op.canChooseDirectories = true
				op.canChooseFiles = false
			} else {
				op.canChooseFiles = true
			}
			panel = op
		} else {
			let sp = NSSavePanel()
			sp.canCreateDirectories = options.bool("create-directories", default: true)
			panel = sp
		}

		let title = options.string("title")
		if !title.isEmpty { panel.title = title }
		let message = options.string("message")
		if !message.isEmpty { panel.message = message }
		let prompt = options.string("button1")
		if !prompt.isEmpty { panel.prompt = prompt }

		let dir = options.string("with-directory")
		if !dir.isEmpty {
			panel.directoryURL = URL(fileURLWithPath: (dir as NSString).expandingTildeInPath)
		}
		let file = options.string("with-file")
		if !file.isEmpty {
			panel.nameFieldStringValue = file
		}

		let exts = options.array("extensions")
		if !exts.isEmpty && !options.bool("no-extension-hide") {
			panel.allowedContentTypes = exts.compactMap { ext -> UTType? in
				UTType(filenameExtension: ext)
			}
		}

		var r = ControlResult()
		let resp = panel.runModal()
		if resp == .OK {
			if let op = panel as? NSOpenPanel {
				let urls = op.urls
				r.values = urls.map { $0.path }
				r.buttonLabel = "OK"
				r.buttonIndex = 0
			} else {
				if let url = panel.url {
					r.values = [url.path]
				}
				r.buttonLabel = "OK"
				r.buttonIndex = 0
			}
		} else {
			r.exit = .cancel
			r.buttonLabel = "Cancel"
		}
		return r
	}
}

import UniformTypeIdentifiers

final class OpenControl: Control {
	static var scope: String { "open" }
	private let inner = FilePickerControl(mode: .open)
	var optionDefinitions: [OptionDefinition] { inner.optionDefinitions }
	func run(options: ParsedOptions) -> ControlResult { inner.run(options: options) }
}

final class SaveControl: Control {
	static var scope: String { "save" }
	private let inner = FilePickerControl(mode: .save)
	var optionDefinitions: [OptionDefinition] { inner.optionDefinitions }
	func run(options: ParsedOptions) -> ControlResult { inner.run(options: options) }
}
