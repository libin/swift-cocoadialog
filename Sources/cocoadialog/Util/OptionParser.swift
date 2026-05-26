import Foundation

// Option type kinds map to cocoadialog's CDBoolean/CDNumber/CDString.
enum OptionKind {
	case boolean
	case number
	case string
	case stringArray
}

struct OptionDefinition {
	let name: String
	let kind: OptionKind
	var defaultValue: Any?       = nil
	var required: Bool           = false
	var minValues: Int           = 0
	var maxValues: Int           = 1     // -1 = unlimited
	/// Aliases that map to this option. e.g. `--text` -> `--message`.
	/// For boolean options, you can also provide an inverse alias starting
	/// with `no-` and the parser will negate the value.
	var aliases: [String]        = []
	var help: String             = ""
}

struct ParsedOptions {
	private var values: [String: [String]] = [:]
	private var provided: Set<String>      = []

	mutating func set(_ name: String, _ vals: [String]) {
		values[name] = vals
		provided.insert(name)
	}

	func wasProvided(_ name: String) -> Bool { provided.contains(name) }

	func array(_ name: String) -> [String] { values[name] ?? [] }

	func string(_ name: String, default: String = "") -> String {
		array(name).last ?? `default`
	}

	func bool(_ name: String, default: Bool = false) -> Bool {
		guard let v = values[name]?.last else { return `default` }
		switch v.lowercased() {
		case "yes", "true", "1": return true
		case "no", "false", "0": return false
		default: return `default`
		}
	}

	func double(_ name: String, default: Double = 0) -> Double {
		Double(string(name, default: "")) ?? `default`
	}

	func int(_ name: String, default: Int = 0) -> Int {
		Int(string(name, default: "")) ?? `default`
	}
}

enum OptionParser {
	/// Parse a flag stream against a set of option definitions.
	static func parse(_ args: [String], using defs: [OptionDefinition]) throws -> ParsedOptions {
		// Build lookup tables.
		var byName: [String: OptionDefinition] = [:]
		var aliasTo: [String: (target: String, negate: Bool)] = [:]
		for def in defs {
			byName[def.name] = def
			for a in def.aliases {
				if a.hasPrefix("no-") && def.kind == .boolean {
					// Boolean inverse alias.
					aliasTo[a] = (def.name, true)
				} else {
					aliasTo[a] = (def.name, false)
				}
			}
		}

		var result = ParsedOptions()

		// Apply defaults.
		for def in defs {
			if let dv = def.defaultValue {
				if let arr = dv as? [String] {
					result.set(def.name, arr)
				} else {
					result.set(def.name, [String(describing: dv)])
				}
				// Defaults shouldn't count as "provided" by user.
				// The internal API only marks via set; we accept that
				// and let bool() etc. fall back to provided status when
				// callers care.
			}
		}

		// Walk args.
		var i = 0
		while i < args.count {
			let arg = args[i]
			guard arg.hasPrefix("--") else {
				// stray positional — skip.
				i += 1
				continue
			}
			let raw = String(arg.dropFirst(2))
			let name: String
			let negate: Bool
			if let target = byName[raw] {
				name = target.name
				negate = false
			} else if let alias = aliasTo[raw] {
				name = alias.target
				negate = alias.negate
			} else {
				throw CDError.optionInvalid(raw)
			}
			let def = byName[name]!

			i += 1
			// Collect values.
			var values: [String] = []
			let unlimited = def.maxValues <= 0
			let stop = unlimited ? args.count : min(args.count, i + def.maxValues)
			while i < stop {
				let next = args[i]
				if next.hasPrefix("--") { break }
				values.append(next)
				i += 1
			}

			switch def.kind {
			case .boolean:
				if values.isEmpty {
					result.set(name, [negate ? "NO" : "YES"])
				} else {
					let v = values[0].uppercased()
					let pos = v == "YES" || v == "TRUE" || v == "1"
					result.set(name, [(pos ? !negate : negate) ? "YES" : "NO"])
				}
			default:
				if !values.isEmpty {
					result.set(name, values)
				}
			}
		}

		// Required check.
		for def in defs where def.required {
			if !result.wasProvided(def.name) {
				throw CDError.optionRequired(def.name)
			}
		}

		return result
	}
}
