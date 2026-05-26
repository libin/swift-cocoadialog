import Foundation

final class ControlRunner {
	let control: Control
	let options: ParsedOptions
	private(set) var exitCode: ExitCode = .ok

	init(control: Control, options: ParsedOptions) {
		self.control = control
		self.options = options
	}

	func run() {
		let r = control.run(options: options)
		exitCode = r.exit

		// Output formatting.
		let stringOutput = options.bool("string-output")
		let suppressNewline = options.bool("no-newline")

		var lines: [String] = []
		if stringOutput {
			if let label = r.buttonLabel {
				lines.append("button:\t\(label)")
			}
			let body = r.values.dropFirst().joined(separator: "\n")
			if !body.isEmpty {
				lines.append("value:\t\(body)")
			}
		} else {
			lines = r.values
		}

		var out = lines.joined(separator: "\n")
		if !suppressNewline && !out.isEmpty {
			out += "\n"
		}
		FileHandle.standardOutput.write(out.data(using: .utf8) ?? Data())
	}
}
