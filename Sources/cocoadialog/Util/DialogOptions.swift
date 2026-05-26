import Foundation

/// Options shared by every control (matches CocoaDialog's CDDialog options).
enum DialogOptions {
	static let common: [OptionDefinition] = [
		OptionDefinition(name: "title",      kind: .string, help: "Window title bar text"),
		OptionDefinition(name: "header",     kind: .string, aliases: ["alert"], help: "Bold heading inside the dialog"),
		OptionDefinition(name: "message",    kind: .string, aliases: ["informative-text", "text"], help: "Body / informative text"),
		OptionDefinition(name: "icon",       kind: .string, help: "Built-in icon name (info, caution, …)"),
		OptionDefinition(name: "icon-file",  kind: .string, help: "Custom icon path"),
		OptionDefinition(name: "buttons",    kind: .stringArray, defaultValue: ["OK"], maxValues: -1, help: "Button labels (right to left rendering)"),
		OptionDefinition(name: "button1",    kind: .string, aliases: [], help: "Alias for first button"),
		OptionDefinition(name: "button2",    kind: .string, help: "Alias for second button"),
		OptionDefinition(name: "button3",    kind: .string, help: "Alias for third button"),
		OptionDefinition(name: "default-button", kind: .string, help: "Highlight this button as the default"),
		OptionDefinition(name: "cancel-button",  kind: .string, help: "Bind ESC to this button"),
		OptionDefinition(name: "width",      kind: .number, help: "Panel content width"),
		OptionDefinition(name: "height",     kind: .number, help: "Panel content height"),
		OptionDefinition(name: "min-width",  kind: .number, help: "Panel content min width"),
		OptionDefinition(name: "min-height", kind: .number, help: "Panel content min height"),
		OptionDefinition(name: "string-output", kind: .boolean, help: "Print 'button:\\tNAME\\nvalue:\\tVAL'"),
		OptionDefinition(name: "no-newline", kind: .boolean, help: "Suppress trailing newline on stdout"),
		OptionDefinition(name: "vibrancy",   kind: .boolean, defaultValue: "NO", help: "Translucent panel (default NO)"),
		OptionDefinition(name: "float",      kind: .boolean, defaultValue: "YES", aliases: ["no-float"], help: "Floating panel level"),
		OptionDefinition(name: "timeout",    kind: .number, help: "Auto-close after N seconds"),
	]
}
