#!/usr/bin/env bash
# Fetches and installs an iOS App Store provisioning profile from App Store Connect.
# Usage: install-ios-profile.sh <bundle-id>
# Prints the profile name to stdout — used by CI: PP_NAME=$(./scripts/install-ios-profile.sh com.nguyentheanh.burnrate)
#
# Requires: asccli, jq
# Requires env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY

set -euo pipefail

BUNDLE_ID="${1:-com.nguyentheanh.burnrate}"
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

# Resolve bundle ID resource ID (iOS platform)
BUNDLE_ID_ID=$(asc bundle-ids list --identifier "$BUNDLE_ID" --platform ios \
  | jq -r '.data[0].id')

if [ -z "$BUNDLE_ID_ID" ] || [ "$BUNDLE_ID_ID" = "null" ]; then
  echo "Error: bundle ID '$BUNDLE_ID' not found in App Store Connect (platform=ios)" >&2
  exit 1
fi

# Fetch IOS_APP_STORE profile
PROFILE_JSON=$(asc profiles list --bundle-id-id "$BUNDLE_ID_ID" --type IOS_APP_STORE)
PROFILE_CONTENT=$(echo "$PROFILE_JSON" | jq -r '.data[0].profileContent // .data[0].attributes.profileContent')

if [ -z "$PROFILE_CONTENT" ] || [ "$PROFILE_CONTENT" = "null" ]; then
  echo "Error: no IOS_APP_STORE profile found for bundle ID '$BUNDLE_ID'" >&2
  exit 1
fi

# Decode (ASC returns non-line-wrapped base64; -A handles that) and install
PP_PATH="$WORK_DIR/ios.mobileprovision"
printf '%s' "$PROFILE_CONTENT" \
  | openssl base64 -d -A \
  | cat > "$PP_PATH"

security cms -D -i "$PP_PATH" > "$WORK_DIR/profile.plist"
PP_UUID=$(/usr/libexec/PlistBuddy -c 'Print UUID' "$WORK_DIR/profile.plist")
PP_NAME=$(/usr/libexec/PlistBuddy -c 'Print Name' "$WORK_DIR/profile.plist")

mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
cp "$PP_PATH" "$HOME/Library/MobileDevice/Provisioning Profiles/$PP_UUID.mobileprovision"

echo "Installed: $PP_NAME ($PP_UUID)" >&2
echo "$PP_NAME"
