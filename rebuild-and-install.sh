#!/usr/bin/env bash
# rebuild-and-install.sh — Build and install VisionClaw to iPhone
# Runs weekly to refresh the free dev certificate (expires every 7 days)
# LaunchAgent: com.isdc.visionclaw-weekly-rebuild

set -euo pipefail

LOG="/opt/homebrew/var/log/visionclaw-rebuild.log"
echo "=== VisionClaw Rebuild $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG"

# Step 1: Build
echo "[BUILD] Starting xcodebuild..." >> "$LOG"
cd /Users/isdc/VisionClaw/samples/CameraAccess
BUILD_OUTPUT=$(xcodebuild \
    -project CameraAccess.xcodeproj \
    -scheme CameraAccess \
    -destination 'generic/platform=iOS' \
    -allowProvisioningUpdates \
    build 2>&1)

if echo "$BUILD_OUTPUT" | grep -q "BUILD SUCCEEDED"; then
    echo "[BUILD] SUCCESS" >> "$LOG"
else
    echo "[BUILD] FAILED" >> "$LOG"
    echo "$BUILD_OUTPUT" | tail -20 >> "$LOG"
    exit 1
fi

# Step 2: Find connected device
DEVICE_ID=$(xcrun devicectl list devices 2>/dev/null | grep "available" | head -1 | awk '{for(i=1;i<=NF;i++) if($i ~ /^[A-F0-9]{8}-/) print $i}')

if [[ -z "$DEVICE_ID" ]]; then
    echo "[INSTALL] No device connected — skipping install" >> "$LOG"
    exit 0
fi

echo "[INSTALL] Device: ${DEVICE_ID}" >> "$LOG"

# Step 3: Find the built .app
APP_PATH="/Users/isdc/Library/Developer/Xcode/DerivedData/CameraAccess-dvtvpvflmpqsfbfeewfxnwrttfdr/Build/Products/Debug-iphoneos/CameraAccess.app"

if [[ ! -d "$APP_PATH" ]]; then
    echo "[INSTALL] App not found at expected path — searching..." >> "$LOG"
    APP_PATH=$(find /Users/isdc/Library/Developer/Xcode/DerivedData -name "CameraAccess.app" -path "*/Debug-iphoneos/*" 2>/dev/null | head -1)
fi

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
    echo "[INSTALL] FAILED — could not find CameraAccess.app" >> "$LOG"
    exit 1
fi

# Step 4: Install
INSTALL_OUTPUT=$(xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH" 2>&1)

if echo "$INSTALL_OUTPUT" | grep -q "App installed"; then
    echo "[INSTALL] SUCCESS — $(echo "$INSTALL_OUTPUT" | grep bundleID)" >> "$LOG"
else
    echo "[INSTALL] FAILED" >> "$LOG"
    echo "$INSTALL_OUTPUT" >> "$LOG"
    exit 1
fi

echo "[DONE] VisionClaw rebuilt and installed at $(date '+%H:%M:%S')" >> "$LOG"
echo "" >> "$LOG"
