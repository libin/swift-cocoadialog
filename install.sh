#!/usr/bin/env bash
#
# install.sh — build swift-cocoadialog and swap it into TextMate's Bundle
# Support CocoaDialog.app, re-signing the bundle so macOS does not SIGKILL it.
#
# The bundled binary lives inside a code-signed .app. Copying a new binary in
# breaks the bundle seal and macOS kills the process on launch (Killed: 9 /
# exit 137). This script always re-signs after copying, so that never happens.
#
# Signing order matters. `swift build` emits a linker-signed ad-hoc signature
# (flags=0x20002 adhoc,linker-signed) with "Info.plist=not bound". Signing only
# the .app does NOT replace it, so the executable never binds to the bundle's
# Info.plist and `codesign -v` reports "invalid Info.plist". So: sign the inner
# binary first, then the bundle.
#
# Usage:
#   ./install.sh              # build release, install, re-sign, verify
#   ./install.sh --no-build   # install the existing .build/release binary
#
# Override the target app bundle with COCOADIALOG_APP=/path/to/CocoaDialog.app
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

APP="${COCOADIALOG_APP:-$HOME/Library/Application Support/TextMate/Managed/Bundles/Bundle Support.tmbundle/Support/shared/bin/CocoaDialog.app}"
BIN_SRC="$REPO_DIR/.build/release/cocoadialog"
BUILD=1
[ "${1:-}" = "--no-build" ] && BUILD=0

log()  { printf '\033[1m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; }

# --- build -----------------------------------------------------------------
if [ "$BUILD" -eq 1 ]; then
	log "Building release…"
	swift build -c release
else
	log "Skipping build (--no-build)"
fi
[ -x "$BIN_SRC" ] || { err "built binary not found at $BIN_SRC — run without --no-build"; exit 1; }

# --- locate the destination bundle -----------------------------------------
[ -d "$APP" ] || { err "CocoaDialog.app not found: $APP (set COCOADIALOG_APP to override)"; exit 1; }
PLIST="$APP/Contents/Info.plist"
[ -f "$PLIST" ] || { err "bundle has no Info.plist: $PLIST"; exit 1; }

# The executable name must match CFBundleExecutable EXACTLY. On a
# case-insensitive filesystem a mismatch still launches, so it hides until
# codesign (which compares literally) refuses to bind the executable to the
# bundle and reports "invalid Info.plist". Normalize to the .app's own name,
# which is also what TextMate's ui.rb invokes.
WANT_EXEC="$(basename "$APP" .app)"   # CocoaDialog
CUR_EXEC="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PLIST" 2>/dev/null || true)"
if [ "$CUR_EXEC" != "$WANT_EXEC" ]; then
	warn "CFBundleExecutable is '$CUR_EXEC' but should be '$WANT_EXEC' — fixing"
	/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $WANT_EXEC" "$PLIST"
fi
DST="$APP/Contents/MacOS/$WANT_EXEC"
# Rename an existing differently-cased executable so the on-disk name matches.
if [ ! -e "$DST" ]; then
	FOUND="$(find "$APP/Contents/MacOS" -maxdepth 1 -iname "$WANT_EXEC" ! -name '*.bak' | head -1 || true)"
	if [ -n "$FOUND" ] && [ "$FOUND" != "$DST" ]; then
		warn "executable is named '$(basename "$FOUND")' — renaming to '$WANT_EXEC'"
		mv "$FOUND" "$DST.tmp-rename" && mv "$DST.tmp-rename" "$DST"
	fi
fi

# --- back up the pristine original exactly once ----------------------------
# Backups go OUTSIDE the bundle: extra Mach-O files in Contents/MacOS/ get
# swept into the seal and signed as nested code.
BAKDIR="$(dirname "$APP")/cocoadialog-backups"
if [ ! -e "$BAKDIR/$WANT_EXEC.objc.bak" ] && [ -e "$DST" ]; then
	mkdir -p "$BAKDIR"
	log "Backing up original → $BAKDIR/$WANT_EXEC.objc.bak"
	cp "$DST" "$BAKDIR/$WANT_EXEC.objc.bak"
fi
# Evict any stale backups a previous version of this script left inside.
for stale in "$APP/Contents/MacOS/"*.bak; do
	[ -e "$stale" ] || continue
	mkdir -p "$BAKDIR"
	warn "moving stale in-bundle backup out: $(basename "$stale")"
	mv "$stale" "$BAKDIR/"
done

# --- install + re-sign -----------------------------------------------------
log "Installing binary into bundle"
cp "$BIN_SRC" "$DST"
log "Re-signing (inner binary, then bundle) — required, or macOS SIGKILLs it"
codesign --force -s - "$DST"
codesign --force -s - "$APP"

# --- verify: seal must be intact AND the binary must actually launch -------
log "Verifying bundle seal"
if ! codesign -v "$APP" 2>&1; then
	err "bundle seal invalid after signing — the binary would be at risk of SIGKILL"
	exit 1
fi

log "Smoke test: launching bundled binary (--version)"
VER="$("$DST" --version 2>&1 | head -1 || true)"
if [ -z "$VER" ]; then
	err "bundled binary produced no output — launch is likely blocked (bad signature?)"
	exit 1
fi

log "Installed OK: $VER"
log "sha: $(shasum "$DST" | awk '{print $1}')"
log "Done. Binary changes are live immediately (no TextMate/pi restart needed)."
