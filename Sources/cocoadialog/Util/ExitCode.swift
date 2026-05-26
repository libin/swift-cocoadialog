import Foundation

// Exit codes match cocoadialog 3.0 conventions.
enum ExitCode: Int32 {
	case ok = 0
	case cancel = 1
	case timeout = 124
	case controlUnknown = 31
	case controlFailure = 32
	case optionInvalid = 51
	case optionRequired = 52
	case unknown = 255
}

enum CDError: Error {
	case optionInvalid(String)
	case optionRequired(String)
	case controlFailure(String)
}
