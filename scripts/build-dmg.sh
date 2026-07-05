#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")
APP="$ROOT/dist/FreeThumb.app"
STAGING="$ROOT/dist/dmg-root"
BACKGROUND="$ROOT/dist/dmg-background.png"
RW_DMG="$ROOT/dist/FreeThumb-rw.dmg"
OUTPUT="$ROOT/dist/FreeThumb-macOS-$VERSION.dmg"
MOUNT_POINT="/private/tmp/freethumb-dmg-mount"
VOLUME_NAME="FreeThumb Installer"
DEVICE=""

cleanup() {
  if [ -n "$DEVICE" ]; then
    hdiutil detach "$DEVICE" -quiet || true
  fi
  if ! mount | grep -F " on $MOUNT_POINT " >/dev/null 2>&1; then
    rm -rf "$MOUNT_POINT" "$STAGING" "$RW_DMG"
  fi
}

if hdiutil info | grep -F "$RW_DMG" >/dev/null 2>&1; then
  printf 'A previous FreeThumb DMG build is still mounted. Eject it before retrying.\n' >&2
  exit 1
fi

trap cleanup EXIT INT TERM

"$ROOT/scripts/build-app.sh"

rm -rf "$STAGING" "$MOUNT_POINT" "$RW_DMG" "$OUTPUT"
mkdir -p "$STAGING/.background" "$MOUNT_POINT"
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

DEVICE=$(hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen -mountpoint "$MOUNT_POINT" \
  | awk -v mount_point="$MOUNT_POINT" '$NF == mount_point { print $1; exit }')

if [ -z "$DEVICE" ]; then
  printf 'Unable to identify the mounted DMG device.\n' >&2
  exit 1
fi

osascript <<APPLESCRIPT
tell application "Finder"
  set dmgFolder to POSIX file "$MOUNT_POINT" as alias
  open dmgFolder
  delay 1
  set dmgWindow to container window of dmgFolder
  set current view of dmgWindow to icon view
  set toolbar visible of dmgWindow to false
  set statusbar visible of dmgWindow to false
  set pathbar visible of dmgWindow to false
  set bounds of dmgWindow to {180, 120, 900, 700}
  set theViewOptions to icon view options of dmgWindow
  set arrangement of theViewOptions to not arranged
  set icon size of theViewOptions to 112
  set text size of theViewOptions to 13
  set background picture of theViewOptions to file ".background:installer-background.png" of dmgFolder
  set position of item "FreeThumb.app" of dmgFolder to {175, 245}
  set position of item "Applications" of dmgFolder to {545, 245}
  set extension hidden of item "FreeThumb.app" of dmgFolder to true
  update dmgFolder without registering applications
  delay 2
  close dmgWindow
  delay 1
end tell
APPLESCRIPT

sync
hdiutil detach "$DEVICE" -quiet
DEVICE=""

hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$OUTPUT" >/dev/null
printf 'Built %s\n' "$OUTPUT"
