#!/bin/bash
#
# adversary_screenshot.sh — One command, one screenshot. No excuses.
#
# Usage:  ./scripts/adversary_screenshot.sh
# Output: /tmp/adversary_screenshot.png
#
# Prerequisite: App must be built (xcodebuild build)
# The script installs and launches with -UITesting (mock data, no permission dialogs)
#

set -eo pipefail

SIM="1EC79950-6704-47D0-BDF8-2C55236B4B40"
SCREENSHOT_PATH="/tmp/adversary_screenshot.png"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"

echo "=== Adversary Screenshot ==="

# 1. Find built app
APP_PATH=$(find "$DERIVED_DATA"/FocusBlox-*/Build/Products/Debug-iphonesimulator -name "FocusBlox.app" -maxdepth 1 2>/dev/null | head -1)
if [ -z "$APP_PATH" ]; then
    echo "No built app found. Run: xcodebuild build -project FocusBlox.xcodeproj -scheme FocusBlox -destination 'id=$SIM'"
    exit 1
fi
BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw "$APP_PATH/Info.plist")
echo "[1/4] Found app: $BUNDLE_ID"

# 2. Ensure simulator is running with UI
open -a Simulator --args -CurrentDeviceUDID "$SIM" 2>/dev/null || true
xcrun simctl boot "$SIM" 2>/dev/null || true
sleep 2
echo "[2/4] Simulator ready"

# 3. Install and launch with mock data
xcrun simctl terminate "$SIM" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$SIM" "$APP_PATH"
xcrun simctl launch "$SIM" "$BUNDLE_ID" -UITesting
echo "[3/4] App launched with mock data"

# 4. Wait for render + take screenshot
sleep 5
rm -f "$SCREENSHOT_PATH" 2>/dev/null || true
xcrun simctl io "$SIM" screenshot "$SCREENSHOT_PATH"

SIZE=$(stat -f%z "$SCREENSHOT_PATH" 2>/dev/null || echo "0")
echo "[4/4] Done!"
echo ""
echo "=== SUCCESS ==="
echo "Screenshot: $SCREENSHOT_PATH ($SIZE bytes)"
echo "View:       open $SCREENSHOT_PATH"
