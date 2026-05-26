# swift-cocoadialog

A Swift+AppKit reimplementation of [cocoadialog](https://github.com/cocoadialog/cocoadialog)
3.0's command-line interface. Drop-in compatible: install the produced
`cocoadialog` binary anywhere your scripts already point to.

**Not affiliated with the original cocoadialog project.** This is a
clean-room rewrite to provide a maintained, MIT-licensed alternative
that builds cleanly on macOS 14+ and Apple Silicon.

## Status

Early scaffolding. Implemented controls listed in `STATUS.md`.

## Building

```sh
swift build -c release
cp .build/release/cocoadialog /usr/local/bin/
```

To deploy into TextMate's Bundle Support:

```sh
DST="$HOME/Library/Application Support/TextMate/Managed/Bundles/Bundle Support.tmbundle/Support/shared/bin/CocoaDialog.app/Contents/MacOS/CocoaDialog"
cp .build/release/cocoadialog "$DST"
```

## CLI

```
cocoadialog <control> [options]
```

Controls: `msgbox`, `inputbox`, `textbox`, `dropdown`, `radio`, `checkbox`,
`slider`, `progressbar`, `open`, `save`, `fileselect`, `filesave`,
plus aliases (`yesno`, `question`, `ok-msgbox`, `standard-input`, etc).

Run `cocoadialog <control> --help` for control-specific options.

## License

MIT
