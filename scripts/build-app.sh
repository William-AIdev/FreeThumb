#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP="$ROOT/dist/FreeThumb.app"

cd "$ROOT"
swift build -c release --product FreeThumb

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/FreeThumb" "$APP/Contents/MacOS/FreeThumb"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
for localization in "$ROOT"/Resources/*.lproj; do
  cp -R "$localization" "$APP/Contents/Resources/"
done
codesign --force --deep --sign - "$APP"

printf 'Built %s\n' "$APP"
