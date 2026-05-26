import Foundation

/// Aliases that resolve to a primary control with default-flag injection.
/// e.g. `cocoadialog question` -> `msgbox` with --buttons "Yes No Cancel".
struct ControlAlias {
	let scope: String
	let injectFlags: [String]

	static func resolve(_ raw: String) -> ControlAlias {
		switch raw {
		case "ok-msgbox":
			return ControlAlias(scope: "msgbox", injectFlags: ["--buttons", "OK"])
		case "yesno-msgbox", "question":
			return ControlAlias(scope: "msgbox", injectFlags: ["--buttons", "Yes", "No", "Cancel"])
		case "ok-cancel":
			return ControlAlias(scope: "msgbox", injectFlags: ["--buttons", "OK", "Cancel"])
		case "secure-input":
			return ControlAlias(scope: "inputbox", injectFlags: ["--secure"])
		case "secure-standard-inputbox":
			return ControlAlias(scope: "inputbox", injectFlags: ["--secure", "--buttons", "OK", "Cancel"])
		case "standard-input", "standard-inputbox":
			return ControlAlias(scope: "inputbox", injectFlags: ["--buttons", "OK", "Cancel"])
		case "standard-dropdown":
			return ControlAlias(scope: "dropdown", injectFlags: ["--buttons", "OK", "Cancel"])
		case "filesave":
			return ControlAlias(scope: "save", injectFlags: [])
		case "fileselect":
			return ControlAlias(scope: "open", injectFlags: [])
		default:
			return ControlAlias(scope: raw, injectFlags: [])
		}
	}

	/// Prepend injected flags so user-provided ones still override.
	func applyDefaults(to flags: [String]) -> [String] {
		injectFlags + flags
	}
}
