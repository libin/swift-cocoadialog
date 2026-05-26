import AppKit

/// All cocoadialog controls implement this protocol.
/// Subclassing pattern from CocoaDialog 3.0 is preserved as composition:
/// each Control declares its options and renders/owns its dialog.
protocol Control: AnyObject {
	/// Subcommand name on the CLI (e.g. "msgbox", "input").
	static var scope: String { get }

	/// Combined option definitions: dialog-wide + control-specific.
	var optionDefinitions: [OptionDefinition] { get }

	/// Build and run the dialog, populating `result`.
	func run(options: ParsedOptions) -> ControlResult
}

struct ControlResult {
	/// Lines printed to stdout. cocoadialog's `--string-output` format is
	/// "args echo\nbutton:\t<name>\nvalue:\t<value...>".
	/// For now, we emit a plain numeric button index + values.
	var buttonIndex: Int? = nil
	var buttonLabel: String? = nil
	/// Each entry becomes one stdout line. Values that contain newlines
	/// are emitted verbatim (so multiline textbox content works).
	var values: [String] = []
	var exit: ExitCode = .ok
}
