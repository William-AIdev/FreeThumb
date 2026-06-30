#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP="$ROOT/dist/FreeThumb.app"

cd "$ROOT"
swift build -c release --product FreeThumb

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/FreeThumb" "$APP/Contents/MacOS/FreeThumb"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"

printf 'Built %s\n' "$APP"
