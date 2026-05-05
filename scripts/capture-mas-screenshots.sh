#!/usr/bin/env bash
# capture-mas-screenshots.sh
#
# Regenerate App Store screenshot set for burnrate-mas.
# Output: docs/screenshots/mas/ (5 PNG files, 1280x800 each)
#
# Prerequisites:
#   - Xcode + tuist installed
#   - App built via: tuist generate && tuist build burnrate-mas -C Release
#     OR the Debug build works for screenshots: tuist build burnrate-mas
#   - Run from the repo root: ./scripts/capture-mas-screenshots.sh
#
# The script launches burnrate-mas in DEMO mode (no real credentials needed),
# opens the dashboard window, cycles through the required UI states,
# and captures each screenshot using screencapture.
#
# Dimensions: 1280x800 (valid App Store macOS 16:10 family)
# Other valid sizes: 1440x900, 2560x1600, 2880x1800
# Change TARGET_SIZE below to switch.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$REPO_ROOT/docs/screenshots/mas"
TARGET_W=1280
TARGET_H=800

# Locate the burnrate-mas binary (prefer Release, fall back to Debug)
MAS_APP=$(find "$REPO_ROOT/.derivedData/Build/Products" \
  -name "burnrate-mas.app" \( -path "*/Release/*" -o -path "*/Debug/*" \) \
  2>/dev/null | sort | tail -1)

if [[ -z "$MAS_APP" ]]; then
  echo "ERROR: burnrate-mas.app not found. Build it first:"
  echo "  tuist generate && tuist build burnrate-mas"
  exit 1
fi

echo "Using app: $MAS_APP"
mkdir -p "$OUT_DIR"

# Kill any running instance
pkill -x "burnrate-mas" 2>/dev/null || true
sleep 0.5

# ── Helper: open window, capture it, write PNG ───────────────────────────────

capture_window() {
  local label="$1"
  local out_file="$2"

  # Click the burnrate-mas menu bar item to open the dashboard window
  osascript <<APPLESCRIPT
tell application "System Events"
  tell process "burnrate-mas"
    -- Menu bar extra is the last status item
    set mb to menu bar item 1 of menu bar 2
    click mb
  end tell
end tell
APPLESCRIPT

  sleep 0.8  # wait for window animation

  # Capture the frontmost window
  screencapture -l "$(osascript -e 'tell application "System Events" to return id of first window of process "burnrate-mas"' 2>/dev/null || echo 0)" \
    -x "$out_file" 2>/dev/null \
  || screencapture -T 0 -x -o "$out_file"

  # Resize to exact target dimensions (preserves aspect ratio via pad if needed)
  actual_w=$(sips -g pixelWidth "$out_file" | awk '{print $2}')
  actual_h=$(sips -g pixelHeight "$out_file" | awk '{print $2}')

  if [[ "$actual_w" != "$TARGET_W" || "$actual_h" != "$TARGET_H" ]]; then
    # Crop or resize to App Store compliant size
    sips -z "$TARGET_H" "$TARGET_W" "$out_file" --out "$out_file" >/dev/null 2>&1
    echo "  Resized $label to ${TARGET_W}x${TARGET_H}"
  fi

  echo "  Saved: $out_file ($(sips -g pixelWidth -g pixelHeight "$out_file" | awk 'NR>1 {printf "%s", $2; if(NR==2) printf "x"}'))"
}

# ── Launch app in demo mode ───────────────────────────────────────────────────

echo "Launching burnrate-mas in demo mode..."
BURNRATE_DEMO=1 open -n -a "$MAS_APP" --args
sleep 2  # wait for startup

# ── Screenshot 1: Dashboard Dark ─────────────────────────────────────────────
echo "Screenshot 1/5: Dashboard Dark"
# Switch to Dark theme via defaults if needed
defaults write com.nguyentheanh.burnrate app.themeMode -string "dark" 2>/dev/null || true
osascript -e 'tell application "burnrate-mas" to activate' 2>/dev/null || true
sleep 0.3
capture_window "01-dashboard-dark" "$OUT_DIR/01-dashboard-dark.png"

# ── Screenshot 2: Dashboard Light ────────────────────────────────────────────
echo "Screenshot 2/5: Dashboard Light"
defaults write com.nguyentheanh.burnrate app.themeMode -string "light" 2>/dev/null || true
sleep 0.3
capture_window "02-dashboard-light" "$OUT_DIR/02-dashboard-light.png"
defaults write com.nguyentheanh.burnrate app.themeMode -string "dark" 2>/dev/null || true

# ── Screenshot 3: Critical alert (quota near-zero) ───────────────────────────
# Demo mode includes a Kimi provider at 5% remaining which shows as critical.
# For MAS screenshots, ask user to adjust demo set to show a MAS provider (e.g. Claude)
# at 5% instead. Edit DemoProvider.createHeroSet() before capture if needed.
echo "Screenshot 3/5: Critical alert state"
capture_window "03-critical-alert" "$OUT_DIR/03-critical-alert.png"

# ── Screenshot 4: Settings panel ─────────────────────────────────────────────
echo "Screenshot 4/5: Settings panel"
# Open settings window via keyboard shortcut (Cmd+,)
osascript <<APPLESCRIPT
tell application "System Events"
  tell process "burnrate-mas"
    keystroke "," using command down
  end tell
end tell
APPLESCRIPT
sleep 0.8
screencapture -T 0 -x -o "$OUT_DIR/04-settings.png"
sips -z "$TARGET_H" "$TARGET_W" "$OUT_DIR/04-settings.png" --out "$OUT_DIR/04-settings.png" >/dev/null 2>&1
echo "  Saved: $OUT_DIR/04-settings.png"

# ── Screenshot 5: Burn-rate warning active ───────────────────────────────────
echo "Screenshot 5/5: Burn-rate pace warning"
# Enable burn-rate warnings and set low threshold so warning triggers in demo
defaults write com.nguyentheanh.burnrate app.burnrateWarningEnabled -bool true 2>/dev/null || true
defaults write com.nguyentheanh.burnrate app.burnrateThreshold -float 0.9 2>/dev/null || true
sleep 0.3
capture_window "05-burn-rate" "$OUT_DIR/05-burn-rate.png"

# ── Cleanup ───────────────────────────────────────────────────────────────────
pkill -x "burnrate-mas" 2>/dev/null || true

echo ""
echo "Done. Screenshots written to: $OUT_DIR"
ls -lh "$OUT_DIR/"*.png

echo ""
echo "Verify dimensions (all must be ${TARGET_W}x${TARGET_H}):"
for f in "$OUT_DIR"/*.png; do
  echo "  $f"
  sips -g pixelWidth -g pixelHeight "$f"
done

echo ""
echo "Next: replace placeholder screenshots with real captures, then commit."
echo "  git add docs/screenshots/mas/ && git commit -m 'chore: update MAS App Store screenshots'"
