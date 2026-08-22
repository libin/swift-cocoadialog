import AppKit

/// Lightweight shell syntax highlighter producing an `NSAttributedString`.
///
/// Used by `DialogPanel` for `--header` / `--message` text that looks like a
/// shell command (e.g. an approval prompt for `rm -rf …`). It only assigns
/// colors/fonts to ranges — every character of the input is preserved verbatim,
/// so the exact command is always shown.
enum ShellHighlighter {
	/// Heuristic: does this text look like a shell command (vs. prose)?
	static func looksLikeCommand(_ s: String) -> Bool {
		if s.isEmpty { return false }
		if s.contains("\n") { return true }
		let checks = [
			"&&|\\|\\||[|;<>]|\\$\\(|`",
			"(^|\\s)--?[A-Za-z0-9]",
			"(^|\\s)(sudo|rm|rmdir|git|npm|npx|pnpm|yarn|node|deno|bun|cp|mv|dd|mkfs\\w*|chmod|chown|chgrp|kill|killall|docker|kubectl|rsync|curl|wget|ssh|scp|tar|find|xargs|brew|apt|pip|make|cargo|go)\\b",
		]
		for p in checks where s.range(of: p, options: .regularExpression) != nil { return true }
		return false
	}

	/// Does this command contain a destructive pattern worth flagging in red?
	static func looksDangerous(_ s: String) -> Bool {
		if s.isEmpty { return false }
		if s.range(of: "\\b(rm|rmdir)\\b", options: .regularExpression) != nil,
			s.range(of: "(^|\\s)-{1,2}[A-Za-z]*[rf]", options: .regularExpression) != nil { return true }
		return s.range(
			of: "\\b(sudo|dd|mkfs\\w*|shutdown|reboot|chmod\\s+-R|chown\\s+-R)\\b|--force\\b|--hard\\b",
			options: .regularExpression
		) != nil
	}

	private static let pattern: NSRegularExpression = {
		// 1 comment | 2 dq-string | 3 sq-string | 4 operator | 5 space + 6 flag | 7 danger word
		let p =
			"(#[^\\n]*)"
			+ "|(\"(?:\\\\.|[^\"\\\\])*\"?)"
			+ "|('(?:\\\\.|[^'\\\\])*'?)"
			+ "|(&&|\\|\\||[|;<>&])"
			+ "|(\\s)(--?[A-Za-z0-9][\\w-]*)"
			+ "|\\b(sudo|rm|rmdir|dd|mkfs\\w*|shutdown|reboot|killall|kill|chmod|chown|chgrp)\\b"
		return try! NSRegularExpression(pattern: p)
	}()

	static func attributed(_ src: String, font: NSFont? = nil) -> NSAttributedString {
		let mono = font ?? NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
		let base: [NSAttributedString.Key: Any] = [.font: mono, .foregroundColor: NSColor.labelColor]
		let colDanger = NSColor.systemRed
		let colFlag = NSColor.systemOrange
		let colOp = NSColor.systemPurple
		let colStr = NSColor.systemGreen
		let colCmt = NSColor.secondaryLabelColor

		let para = NSMutableParagraphStyle()
		para.lineBreakMode = .byWordWrapping

		let out = NSMutableAttributedString()
		func append(_ s: String, _ color: NSColor, bold: Bool = false) {
			guard !s.isEmpty else { return }
			var attrs: [NSAttributedString.Key: Any] = [
				.font: bold ? boldMono(mono) : mono,
				.foregroundColor: color,
				.paragraphStyle: para,
			]
			if color === NSColor.labelColor { attrs = base.merging([.paragraphStyle: para]) { _, b in b } }
			out.append(NSAttributedString(string: s, attributes: attrs))
		}

		let ns = src as NSString
		var last = 0
		let full = NSRange(location: 0, length: ns.length)
		pattern.enumerateMatches(in: src, options: [], range: full) { m, _, _ in
			guard let m else { return }
			let r = m.range
			if r.location > last {
				append(ns.substring(with: NSRange(location: last, length: r.location - last)), .labelColor)
			}
			func g(_ i: Int) -> String? {
				let gr = m.range(at: i)
				return gr.location == NSNotFound ? nil : ns.substring(with: gr)
			}
			if let t = g(1) { append(t, colCmt) }
			else if let t = g(2) { append(t, colStr) }
			else if let t = g(3) { append(t, colStr) }
			else if let t = g(4) { append(t, colOp) }
			else if let fl = g(6) {
				if let sp = g(5) { append(sp, .labelColor) }
				let dangerFlag = fl.range(of: "^-{1,2}[A-Za-z]*[rf]", options: .regularExpression) != nil
				append(fl, dangerFlag ? colDanger : colFlag, bold: dangerFlag)
			} else if let t = g(7) { append(t, colDanger, bold: true) }
			last = r.location + r.length
		}
		if last < ns.length {
			append(ns.substring(with: NSRange(location: last, length: ns.length - last)), .labelColor)
		}
		return out
	}

	private static func boldMono(_ f: NSFont) -> NSFont {
		NSFontManager.shared.convert(f, toHaveTrait: .boldFontMask)
	}
}
