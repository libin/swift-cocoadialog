# swift-cocoadialog

A Swift + AppKit reimplementation of
[cocoadialog](https://github.com/cocoadialog/cocoadialog) 3.0's command-line
interface. Drop-in compatible: install the produced `cocoadialog` binary
anywhere your scripts already point to.

**Not affiliated with the original cocoadialog project.** This is a clean-room
rewrite (no source or assets copied from the GPL-licensed original) to provide a
maintained, MIT-licensed alternative that builds cleanly on macOS 14+ and Apple
Silicon, with no Xcode workspace, no xib files, and no dependencies beyond the
system frameworks.

## Status

Usable. Every dialog used by TextMate's Bundle Support is implemented and
verified against
[CocoaDialog-Test.tmbundle](https://github.com/libin/CocoaDialog-Test.tmbundle).

See [`STATUS.md`](STATUS.md) for the full feature matrix.

## Building

```sh
swift build -c release
cp .build/release/cocoadialog /usr/local/bin/
```

To swap into TextMate's Bundle Support (replacing the original ObjC binary):

```sh
DST="$HOME/Library/Application Support/TextMate/Managed/Bundles/Bundle Support.tmbundle/Support/shared/bin/CocoaDialog.app/Contents/MacOS/CocoaDialog"
cp "$DST" "$DST.objc.bak"          # keep a backup of the original
cp .build/release/cocoadialog "$DST"
```

`CocoaDialog.app` is the executable wrapper; the binary inside is what
`$DIALOG`-style scripts invoke.

## CLI

```
cocoadialog <control> [options]
```

Controls:

- `msgbox`, `inputbox`, `secure-input`, `textbox`
- `dropdown`, `radio`, `checkbox`, `slider`, `progressbar`
- `open` (a.k.a. `fileselect`), `save` (a.k.a. `filesave`)
- `about`

Aliases that inject default flags:

- `ok-msgbox`, `yesno-msgbox`, `question`, `ok-cancel`
- `secure-standard-inputbox`, `standard-input`, `standard-inputbox`
- `standard-dropdown`

Run `cocoadialog <control> --help` for control-specific options.

### Example

```sh
cocoadialog msgbox --title "Hello" --message "Continue?" \
                   --buttons Yes No Cancel --string-output
# stdout: Yes  (or No, or Cancel)
```

```sh
( for i in 0 25 50 75 100; do echo "$i Step $i"; sleep 0.5; done ) \
  | cocoadialog progressbar --title "Loading"
```

## Compatibility notes vs. original cocoadialog

- `--vibrancy` is a no-op; panels are always solid (the original's vibrancy
  rendering is broken on macOS 14+).
- Radio/checkbox use a vertical `NSStackView` of `NSButton`s instead of the
  deprecated `NSMatrix`. Behaviour is identical from the CLI's perspective.
- Backslash escapes in `--text` / `--message` (`\n`, `\t`, `\r`) are interpreted
  the way most shell users expect.
- `--text` is treated as a deprecated alias for `--message` everywhere except
  `inputbox`/`textbox`, where it pre-fills the field (matching upstream's late
  3.x behaviour).

## License

MIT — see [`LICENSE`](LICENSE).
