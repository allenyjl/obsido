#!/bin/bash
# Assemble build/Obsido.app from the SPM build output and ad-hoc sign it.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)"

APP="build/Obsido.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Obsido" "$APP/Contents/MacOS/Obsido"
cp Support/Info.plist "$APP/Contents/Info.plist"
# SPM resource bundles from dependencies (e.g. KeyboardShortcuts localizations)
find "$BIN" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$APP/Contents/Resources/" \;

codesign --force --sign - "$APP"
echo "Built $APP"
