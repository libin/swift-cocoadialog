import Foundation

enum ControlRegistry {
	static func make(scope: String) -> Control? {
		switch scope {
		case MsgboxControl.scope:   return MsgboxControl()
		case InputboxControl.scope: return InputboxControl()
		case TextboxControl.scope:  return TextboxControl()
		// More controls (dropdown, radio, checkbox, slider, progressbar,
		// open, save, fileselect, filesave) come online as they're implemented.
		case "input":               return InputboxControl()  // alias path post-resolve
		default:                    return nil
		}
	}
}
