#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="burnrate.xcworkspace"
SCHEME="burnrate-mas"
TEAM_ID="28DMV2MR8T"
ARCHIVE="/tmp/burnrate-mac-upload.xcarchive"
EXPORT_DIR="/tmp/burnrate-mac-export"
EXPORT_OPTS="/tmp/burnrate-mac-export-options.plist"
INFO_PLIST="Sources/App/Info.plist"
IMESSAGE_CHAT="chat365672485796744826"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$SCRIPT_DIR"

# --- Read current versions ---
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")
CURRENT=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST")
BUILD=$((CURRENT + 1))

# --- Bump build number ---
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$INFO_PLIST"
echo "==> burnrate macOS v${VERSION} (${BUILD})"

# --- Revert on failure ---
revert_build() {
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $CURRENT" "$INFO_PLIST"
  echo "==> Reverted build number to ${CURRENT}"
}
trap revert_build ERR

# --- Changelog ---
if [ -n "${1:-}" ]; then
  BULLETS="• $1"
else
  LAST_TAG=$(git describe --tags --match "tf-mac-*" --abbrev=0 2>/dev/null || echo "")
  if [ -n "$LAST_TAG" ]; then
    BULLETS=$(set +o pipefail; git log --oneline --no-merges "${LAST_TAG}..HEAD" \
      | grep -viE "bump build|agvtool" \
      | awk '{$1=""; print "•" substr($0,2)}' \
      | head -10)
    [ -z "$BULLETS" ] && BULLETS="• build ${BUILD} — no new commits since ${LAST_TAG}"
  else
    TOP_MSG=$(git log --oneline --no-merges -1 | awk '{$1=""; print substr($0,2)}')
    BULLETS="• ${TOP_MSG}"
  fi
fi

echo "==> Changelog:"
echo "$BULLETS"
BULLETS="${BULLETS//\'/}"

# --- Bail if nothing changed ---
if [[ "$BULLETS" == "• build ${BUILD} — no new commits since"* ]]; then
  echo "==> Nothing new since ${LAST_TAG} — skipping upload"
  revert_build
  trap - ERR
  exit 0
fi

# --- Regenerate Xcode project (picks up bumped Info.plist) ---
echo "==> Generating Xcode project..."
tuist generate --no-open

# --- Export options ---
cat > "$EXPORT_OPTS" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>upload</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
</dict>
</plist>
EOF

# --- Archive ---
echo "==> Archiving..."
rm -rf "$ARCHIVE" "$EXPORT_DIR"
xcodebuild archive \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  -quiet

# --- Export + Upload ---
echo "==> Uploading to TestFlight..."
UPLOAD_OUTPUT=$(xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTS" \
  -allowProvisioningUpdates 2>&1)
echo "$UPLOAD_OUTPUT" | grep -E "error:|Export Succeeded|Upload succeeded|FAILED|Progress" || true

if echo "$UPLOAD_OUTPUT" | grep -q "Upload succeeded"; then
  git add "$INFO_PLIST"
  git commit -m "chore: bump macOS build to ${BUILD}"
  git tag "tf-mac-${BUILD}" 2>/dev/null || true
  git push origin main --tags 2>/dev/null || true

  MESSAGE="andrejmat🤖: 🖥️ burnrate macOS build ${BUILD} (v${VERSION}) pushed to TestFlight

${BULLETS}"

  osascript - "$IMESSAGE_CHAT" "$MESSAGE" << 'APPLESCRIPT'
on run argv
  set chatID to item 1 of argv
  set msg to item 2 of argv
  tell application "Messages"
    set targetChat to (first chat whose id is ("any;+;" & chatID))
    send msg to targetChat
  end tell
end run
APPLESCRIPT

  echo "==> Done: macOS build ${BUILD}"
else
  echo "==> Upload failed — reverting build number"
  revert_build
  trap - ERR
  exit 1
fi
trap - ERR
