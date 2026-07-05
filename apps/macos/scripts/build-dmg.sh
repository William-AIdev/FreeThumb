#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")
APP="$ROOT/dist/FreeThumb.app"
STAGING="$ROOT/dist/dmg-root"
BACKGROUND="$ROOT/dist/dmg-background.png"
RW_DMG="$ROOT/dist/FreeThumb-rw.dmg"
OUTPUT="$ROOT/dist/FreeThumb-macOS-$VERSION.dmg"
MOUNT_POINT=""
VOLUME_NAME="FreeThumb Installer"
DEVICE=""

cleanup() {
  if [ -n "$DEVICE" ]; then
    hdiutil detach "$DEVICE" -quiet || true
  fi
  if [ -z "$MOUNT_POINT" ] || ! mount | grep -F " on $MOUNT_POINT " >/dev/null 2>&1; then
    rm -rf "$STAGING" "$RW_DMG"
  fi
}

if hdiutil info | grep -F "$RW_DMG" >/dev/null 2>&1; then
  printf 'A previous FreeThumb DMG build is still mounted. Eject it before retrying.\n' >&2
  exit 1
fi

trap cleanup EXIT INT TERM

"$ROOT/scripts/build-app.sh"

rm -rf "$STAGING" "$RW_DMG" "$OUTPUT"
mkdir -p "$STAGING/.background"
/usr/bin/ditto "$APP" "$STAGING/FreeThumb.app"
ln -s /Applications "$STAGING/Applications"

xcrun swift "$ROOT/scripts/render-dmg-background.swift" \
  "$BACKGROUND" "$ROOT/Resources/AppIcon.png"
cp "$BACKGROUND" "$STAGING/.background/installer-background.png"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDRW \
  "$RW_DMG" >/dev/null

ATTACH_OUTPUT=$(hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen -nobrowse \
  -mountrandom /Volumes)
DEVICE=$(printf '%s\n' "$ATTACH_OUTPUT" | awk -F '\t' \
  '$NF ~ /^\/Volumes\// { sub(/[[:space:]]+$/, "", $1); print $1; exit }')
MOUNT_POINT=$(printf '%s\n' "$ATTACH_OUTPUT" | awk -F '\t' '$NF ~ /^\/Volumes\// { print $NF; exit }')

if [ -z "$DEVICE" ] || [ -z "$MOUNT_POINT" ]; then
  printf 'Unable to identify the mounted DMG device or volume.\n' >&2
  exit 1
fi

DISK_NAME=$(basename "$MOUNT_POINT")
sleep 5

osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$DISK_NAME"
  open
  delay 1
  set dmgWindow to container window
  set current view of dmgWindow to icon view
  set toolbar visible of dmgWindow to false
  set statusbar visible of dmgWindow to false
  set pathbar visible of dmgWindow to false
  set bounds of dmgWindow to {180, 120, 900, 700}
  set theViewOptions to icon view options of dmgWindow
  set arrangement of theViewOptions to not arranged
  set icon size of theViewOptions to 112
  set text size of theViewOptions to 13
  set background picture of theViewOptions to file ".background:installer-background.png"
  set position of item "FreeThumb.app" to {175, 245}
  set position of item "Applications" to {545, 245}
  set extension hidden of item "FreeThumb.app" to true
  close dmgWindow
  delay 1
  open
  set bounds of container window to {180, 120, 890, 690}
  delay 1
  set bounds of container window to {180, 120, 900, 700}
  update without registering applications
  delay 3
  close container window
  end tell
end tell
APPLESCRIPT

sync
if [ ! -f "$MOUNT_POINT/.DS_Store" ]; then
  printf 'Finder did not save the DMG layout metadata; refusing to build an installer without its background.\n' >&2
  exit 1
fi
hdiutil detach "$DEVICE" -quiet
DEVICE=""

hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$OUTPUT" >/dev/null
printf 'Built %s\n' "$OUTPUT"
