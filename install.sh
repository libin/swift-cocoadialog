#!/usr/bin/env bash
#
# install.sh — build swift-cocoadialog and swap it into TextMate's Bundle
# Support CocoaDialog.app, re-signing the bundle so macOS does not SIGKILL it.
#
# The bundled binary lives inside a code-signed .app; copying a new binary in
# breaks the bundle seal and macOS kills it on launch (Killed: 9 / exit 137).
# This script always re-signs (ad-hoc) after copying, so that never happens.
#
# Usage:
#   ./install.sh              # build release, install, re-sign, smoke-test
#   ./install.sh --no-build   # install the existing .build/release binary
#
# Override the target app bundle with COCOADIALOG_APP=/path/to/CocoaDialog.app
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

APP="${COCOADIALOG_APP:-$HOME/Library/Application Support/TextMate/Managed/Bundles/Bundle Support.tmbundle/Support/shared/bin/CocoaDialog.app}"
BIN_SRC="$REPO_DIR/.build/release/cocoadialog"
DST="$APP/Contents/MacOS/CocoaDialog"
BUILD=1
[ "${1:-}" = "--no-build" ] && BUILD=0

log()  { printf '\033[1m==>\033[0m %s\n' "$*"; }
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
[ -e "$DST" ] || { err "binary not found inside bundle: $DST"; exit 1; }

# --- back up the pristine original exactly once ----------------------------
if [ ! -e "$DST.objc.bak" ]; then
	log "Backing up original → $(basename "$DST").objc.bak"
	cp "$DST" "$DST.objc.bak"
fi

# --- install + re-sign (the whole point) -----------------------------------
log "Installing binary into bundle"
cp "$BIN_SRC" "$DST"
log "Re-signing app bundle (ad-hoc) — required, or macOS SIGKILLs it"
codesign --force --deep -s - "$APP"

# --- smoke test: launching the bundled binary must not be killed -----------
log "Smoke test: launching bundled binary (--version)"
VER="$("$DST" --version 2>&1 | head -1 || true)"
if [ -z "$VER" ]; then
	err "bundled binary produced no output — launch is likely blocked (bad signature?)"
	exit 1
fi

log "Installed OK: $VER"
log "sha: $(shasum "$DST" | awk '{print $1}')"
log "Done. Binary changes are live immediately (no TextMate/pi restart needed)."
