import Foundation

enum ControlRegistry {
	static func make(scope: String) -> Control? {
		switch scope {
		case MsgboxControl.scope:      return MsgboxControl()
		case InputboxControl.scope:    return InputboxControl()
		case TextboxControl.scope:     return TextboxControl()
		case DropdownControl.scope:    return DropdownControl()
		case RadioControl.scope:       return RadioControl()
		case CheckboxControl.scope:    return CheckboxControl()
		case SliderControl.scope:      return SliderControl()
		case ProgressbarControl.scope: return ProgressbarControl()
		case OpenControl.scope:        return OpenControl()
		case SaveControl.scope:        return SaveControl()
		// More controls (about) come online as they're implemented.
		case "input":                  return InputboxControl()  // alias path post-resolve
		default:                    return nil
		}
	}
}
