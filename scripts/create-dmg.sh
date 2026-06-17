#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 /path/to/App.app /path/to/output.dmg [Volume Name]" >&2
  exit 64
fi

APP_PATH="$1"
DMG_PATH="$2"
DEFAULT_VOLUME_NAME="Don't Stop"
VOLUME_NAME="${3:-$DEFAULT_VOLUME_NAME}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  exit 66
fi

APP_BUNDLE_NAME="$(basename "$APP_PATH")"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dont-stop-dmg.XXXXXX")"
STAGE_DIR="$WORK_DIR/stage"
RW_DMG="$WORK_DIR/rw.dmg"
MOUNT_DIR="$WORK_DIR/mount"

cleanup() {
  if /sbin/mount | /usr/bin/grep -q "on $MOUNT_DIR "; then
    /usr/bin/hdiutil detach "$MOUNT_DIR" -quiet || true
  fi
  /bin/rm -rf "$WORK_DIR"
}
trap cleanup EXIT

/bin/mkdir -p "$STAGE_DIR" "$MOUNT_DIR"
/bin/cp -R "$APP_PATH" "$STAGE_DIR/$APP_BUNDLE_NAME"
/bin/ln -s /Applications "$STAGE_DIR/Applications"

/bin/rm -f "$DMG_PATH"

/usr/bin/hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGE_DIR" \
  -fs HFS+ \
  -format UDRW \
  -quiet \
  "$RW_DMG"

/usr/bin/hdiutil convert "$RW_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH" \
  -quiet

/usr/bin/hdiutil verify "$DMG_PATH" >/dev/null
echo "Created $DMG_PATH"
