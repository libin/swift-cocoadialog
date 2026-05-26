// swift-cocoadialog: clean-room Swift reimplementation of cocoadialog 3.0.
// MIT licensed. Not affiliated with the original cocoadialog project.

import AppKit

let argv = Array(CommandLine.arguments.dropFirst())

if argv.isEmpty || argv.first == "--help" || argv.first == "-h" {
	Help.printGlobal()
	exit(0)
}

if argv.first == "--version" || argv.first == "-v" {
	print("3.0.0-swift")
	exit(0)
}

let raw = argv[0]
let scope: String

// Resolve aliases (question -> msgbox with Yes/No/Cancel, ok-msgbox -> msgbox, etc.)
let alias = ControlAlias.resolve(raw)
scope = alias.scope

// Strip the leading scope token; the rest are flags.
var flags = Array(argv.dropFirst())

// Apply alias defaults (e.g. question alias seeds buttons=[Yes,No,Cancel]).
flags = alias.applyDefaults(to: flags)

// Build the control by scope.
guard let control = ControlRegistry.make(scope: scope) else {
	FileHandle.standardError.write("error: unknown control: \(raw)\n".data(using: .utf8)!)
	exit(ExitCode.controlUnknown.rawValue)
}

let parsed: ParsedOptions
do {
	parsed = try OptionParser.parse(flags, using: control.optionDefinitions)
} catch let CDError.optionInvalid(name) {
	FileHandle.standardError.write("error: invalid option: --\(name)\n".data(using: .utf8)!)
	exit(ExitCode.optionInvalid.rawValue)
} catch let CDError.optionRequired(name) {
	FileHandle.standardError.write("error: required option missing: --\(name)\n".data(using: .utf8)!)
	exit(ExitCode.optionRequired.rawValue)
} catch {
	FileHandle.standardError.write("error: \(error)\n".data(using: .utf8)!)
	exit(ExitCode.unknown.rawValue)
}

// Run the dialog on the main thread; AppKit requires it.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let runner = ControlRunner(control: control, options: parsed)
runner.run()
exit(runner.exitCode.rawValue)
