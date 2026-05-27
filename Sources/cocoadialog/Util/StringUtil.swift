import Foundation

/// Interpret common backslash escapes (\n, \t, \r, \\) the way cocoadialog does
/// when shells pass literal strings.
func unescapeBackslashes(_ s: String) -> String {
	var out = ""
	out.reserveCapacity(s.count)
	var iter = s.makeIterator()
	while let c = iter.next() {
		if c == "\\" {
			if let next = iter.next() {
				switch next {
				case "n": out.append("\n")
				case "t": out.append("\t")
				case "r": out.append("\r")
				case "\\": out.append("\\")
				case "\"": out.append("\"")
				default:
					out.append("\\")
					out.append(next)
				}
			} else {
				out.append("\\")
			}
		} else {
			out.append(c)
		}
	}
	return out
}
