import Foundation

enum Help {
	static func printGlobal() {
		print("""
		swift-cocoadialog \(ProcessInfo.processInfo.environment["VERSION"] ?? "3.0.0-swift")
		Compatible reimplementation of cocoadialog 3.0 in Swift. MIT licensed.

		USAGE
		    cocoadialog <control> [options]

		CONTROLS (implemented)
		    msgbox          Plain message box with one or more buttons
		    inputbox        Single-line text input
		    textbox         Multi-line text box
		    dropdown        Pop-up menu (single selection)
		    radio           Single-select list of radio buttons
		    checkbox        Multi-select list of checkboxes
		    slider          Numeric slider
		    progressbar     Determinate/indeterminate progress bar (stdin-driven)
		    open            Open-file/folder panel (alias: fileselect)
		    save            Save-file panel (alias: filesave)
		    about           About panel
		    yesno-msgbox    msgbox alias with Yes/No/Cancel buttons
		    ok-msgbox       msgbox alias with OK button
		    standard-input  inputbox alias with OK/Cancel buttons
		    secure-input    inputbox alias with secure (password) field

		COMMON OPTIONS
		    --title <string>             Window title bar
		    --header <string>            Bold heading inside the dialog
		    --message <string>           Body text
		    --buttons <strings…>         Button labels (button[0] = rightmost)
		    --button1 / 2 / 3 <string>   Single-button alias when --buttons not used
		    --default-button <label>     Bind ⏎ to this button
		    --cancel-button <label>      Bind ⎋ to this button
		    --width / --height <number>  Panel content size
		    --vibrancy / --no-vibrancy   Translucent panel (default off)
		    --float / --no-float         Floating panel level
		    --string-output              Print 'button:\\tNAME\\nvalue:\\tVAL'
		    --no-newline                 Suppress trailing newline on stdout

		Run `cocoadialog <control> --help` for control-specific options.
		""")
	}
}
