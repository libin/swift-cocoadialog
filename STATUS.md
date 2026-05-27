# swift-cocoadialog status

All controls used by TextMate's Bundle Support are implemented and visually
verified against
[CocoaDialog-Test.tmbundle](https://github.com/libin/CocoaDialog-Test.tmbundle).

## Implemented

### Infrastructure

- [x] Option parser with typed kinds (boolean / number / string / stringArray)
- [x] Boolean inversion via `no-X` prefix
- [x] Aliases with default-flag injection
- [x] Common options (`--title`, `--header`, `--message`, `--buttons`,
      `--string-output`, etc.)
- [x] Auto-layout dialog panel (header → message → control view → buttons)
- [x] Solid, non-vibrant panel
- [x] Right-to-left button rendering (`--button1` = rightmost / default)
- [x] ESC closes via cancel button
- [x] Backslash escape handling (`\n`, `\t`, `\r`, `\\`) for text fields
- [x] Help: `cocoadialog --help`, `cocoadialog <control> --help`

### Controls

| Control                | Notes                                                                |
|------------------------|----------------------------------------------------------------------|
| `msgbox`               | + aliases `ok-msgbox`, `yesno-msgbox`, `question`, `ok-cancel`        |
| `inputbox`             | `--secure`, `--placeholder`, `--value`, `--text`                      |
| `secure-input`         | alias of `inputbox --secure`                                          |
| `textbox`              | Multi-line, `--editable`, `--file`, `⌘⏎` submits default button       |
| `dropdown`             | `NSPopUpButton`, alias `standard-dropdown`                            |
| `radio`                | `NSButton(.radio)` stack with shared exclusivity                      |
| `checkbox`             | `NSButton(.checkbox)` stack                                           |
| `slider`               | Live label, integer or `--return-float` (2 dp)                        |
| `progressbar`          | stdin-driven (`<percent> <label?>`), auto-closes on EOF, `--stoppable`|
| `open` / `fileselect`  | `NSOpenPanel` (multi-select, dirs only, allowed extensions)           |
| `save` / `filesave`    | `NSSavePanel`                                                         |
| `about`                | Native `NSAlert`-based                                                |

## Pending / nice-to-have

- [x] Markdown rendering for `--header` / `--message` (inline, system parser)
- [x] `--icon` / `--icon-file` rendering (SF Symbols, file paths, .app bundles, base64)
- [x] `--timeout` auto-close (+ `--timeout-default-button`)
- [ ] `--width` / `--height` percentages of screen
- [ ] `--debug` JSON output mode
- [ ] AppleScript bridge mode (was used by some legacy callers)

None of these are blockers for the TextMate Bundle Support use case.
