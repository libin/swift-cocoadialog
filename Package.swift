// swift-tools-version: 5.9
import PackageDescription

let package = Package(
	name: "swift-cocoadialog",
	platforms: [.macOS(.v14)],
	products: [
		.executable(name: "cocoadialog", targets: ["cocoadialog"])
	],
	targets: [
		.executableTarget(
			name: "cocoadialog",
			path: "Sources/cocoadialog"
		)
	]
)
