import AppKit

/// Resolve --icon / --icon-file values into an NSImage.
///
/// Supported sources, in priority order:
///   1. Built-in name: info, caution, application icon, etc.
///   2. SF Symbol via `NSImage(systemSymbolName:)`
///   3. NSImage(named:) (asset catalog / system named icon)
///   4. File path (URL or POSIX), supports ~ expansion
///   5. .app bundle path → NSWorkspace.icon(forFile:)
///   6. Bundle id (`com.apple.Safari`) → NSWorkspace
///   7. data: URL or base64 string
enum IconLoader {
	static func resolve(name: String?, file: String?) -> NSImage? {
		if let f = file, !f.isEmpty {
			if let img = fromPath(f) { return img }
		}
		if let n = name, !n.isEmpty {
			if let img = fromName(n) { return img }
		}
		return nil
	}

	private static func fromName(_ raw: String) -> NSImage? {
		let n = raw.trimmingCharacters(in: .whitespaces)

		// Built-in semantic names.
		switch n.lowercased() {
		case "info", "note", "notice":
			return NSImage(named: NSImage.infoName) ?? sfSymbol("info.circle")
		case "caution", "warning", "alert":
			return NSImage(named: NSImage.cautionName) ?? sfSymbol("exclamationmark.triangle")
		case "stop", "error":
			return NSImage(named: NSImage.stopProgressFreestandingTemplateName) ?? sfSymbol("xmark.octagon")
		case "applicationicon", "app":
			return NSApp.applicationIconImage
		default: break
		}

		// SF Symbol (covers most modern names).
		if let img = sfSymbol(n) { return img }

		// NSImage named lookup (asset / system).
		if let img = NSImage(named: NSImage.Name(n)) { return img }

		// Bundle id → app icon.
		if n.contains("."), let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: n) {
			return NSWorkspace.shared.icon(forFile: url.path)
		}

		return nil
	}

	private static func fromPath(_ raw: String) -> NSImage? {
		let s = raw.trimmingCharacters(in: .whitespaces)

		// data: URL or raw base64 (heuristic: long token, no slash, lots of A-Za-z0-9+/=).
		if s.hasPrefix("data:") {
			if let comma = s.firstIndex(of: ",") {
				let b64 = String(s[s.index(after: comma)...])
				if let data = Data(base64Encoded: b64) {
					return NSImage(data: data)
				}
			}
		}

		// Expand ~ and treat as filesystem path.
		let expanded = (s as NSString).expandingTildeInPath
		if FileManager.default.fileExists(atPath: expanded) {
			// .app bundle → ask Workspace for the rendered icon.
			if expanded.hasSuffix(".app") {
				return NSWorkspace.shared.icon(forFile: expanded)
			}
			return NSImage(contentsOfFile: expanded)
		}

		// file:// URL.
		if let url = URL(string: s), url.isFileURL {
			return NSImage(contentsOf: url)
		}

		// Last-chance base64 (no data: prefix).
		if let data = Data(base64Encoded: s), let img = NSImage(data: data) {
			return img
		}

		return nil
	}

	private static func sfSymbol(_ name: String) -> NSImage? {
		NSImage(systemSymbolName: name, accessibilityDescription: nil)
	}
}
