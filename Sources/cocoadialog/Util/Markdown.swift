import Foundation

/// Render a markdown source into an NSAttributedString using the system parser.
/// Falls back to plain text if parsing fails.
import AppKit

enum Markdown {
	static func attributed(_ source: String, font: NSFont) -> NSAttributedString {
		let s = source.replacingOccurrences(of: "\\n", with: "\n")
		var opts = AttributedString.MarkdownParsingOptions()
		opts.interpretedSyntax = .inlineOnlyPreservingWhitespace
		opts.allowsExtendedAttributes = true
		if let attr = try? AttributedString(markdown: s, options: opts) {
			let ns = NSMutableAttributedString(attributedString: NSAttributedString(attr))
			let full = NSRange(location: 0, length: ns.length)
			ns.addAttribute(.font, value: font, range: full)
			ns.addAttribute(.foregroundColor, value: NSColor.labelColor, range: full)
			return ns
		}
		return NSAttributedString(string: s, attributes: [
			.font: font, .foregroundColor: NSColor.labelColor,
		])
	}
}
