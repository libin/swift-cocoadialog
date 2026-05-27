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

		let stringOutput = options.bool("string-output")
		let json = options.bool("json")
		let suppressNewline = options.bool("no-newline")

		var out: String
		if json {
			let payload: [String: Any] = [
				"button": r.buttonLabel ?? "",
				"buttonIndex": r.buttonIndex ?? -1,
				"values": Array(r.values.dropFirst()),  // first is button label
				"exit": r.exit.rawValue,
			]
			let data = (try? JSONSerialization.data(
				withJSONObject: payload,
				options: [.sortedKeys, .prettyPrinted]
			)) ?? Data()
			out = String(data: data, encoding: .utf8) ?? "{}"
		} else if stringOutput {
			var lines: [String] = []
			if let label = r.buttonLabel {
				lines.append("button:\t\(label)")
			}
			let body = r.values.dropFirst().joined(separator: "\n")
			if !body.isEmpty {
				lines.append("value:\t\(body)")
			}
			out = lines.joined(separator: "\n")
		} else {
			out = r.values.joined(separator: "\n")
		}

		if !suppressNewline && !out.isEmpty {
			out += "\n"
		}
		FileHandle.standardOutput.write(out.data(using: .utf8) ?? Data())
	}
}
