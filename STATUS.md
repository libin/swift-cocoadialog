# swift-cocoadialog status

## Implemented

- [x] Core option parser with type kinds (boolean / number / string / stringArray)
- [x] Boolean alias inversion via `no-X` prefix
- [x] Common dialog options (`--title`, `--header`, `--message`, `--buttons`, etc.)
- [x] Dialog panel with proper auto-layout (header → message → controlView → buttons)
- [x] Solid (non-vibrant) panel by default
- [x] Right-to-left button rendering (button[0] = rightmost)
- [x] ESC → cancel-button
- [x] String output mode (`--string-output`)
- [x] `msgbox`
- [x] `inputbox` (incl. `--secure`, `--placeholder`)
- [x] `textbox` (incl. ⌘⏎ submit, `--editable`, `--file`)
- [x] Aliases: `ok-msgbox`, `yesno-msgbox`, `question`, `ok-cancel`, `secure-input`, `standard-input`, `filesave`, `fileselect`

## Pending

- [ ] `dropdown`
- [ ] `radio` / `checkbox` (NSMatrix)
- [ ] `slider` (with live label, integer/float formatting)
- [ ] `progressbar` (stdin-driven, auto-close on EOF)
- [ ] `open` (NSOpenPanel: directories, multi-select, allowed extensions)
- [ ] `save` (NSSavePanel)
- [ ] `about`
- [ ] Markdown rendering for `--header` / `--message`
- [ ] `--icon` / `--icon-file` rendering
- [ ] `--timeout` auto-close
- [ ] `--width` / `--height` percentages of screen
- [ ] CocoaDialog Test bundle: parity verification on every test
