#!/usr/bin/env bash
# daily-healthcheck.sh — Daily health check for VisionClaw stack
# Verifies: proxy, signaling, ngrok, gateway, app cert age
# LaunchAgent: com.isdc.visionclaw-daily-healthcheck

set -euo pipefail

LOG="/opt/homebrew/var/log/visionclaw-healthcheck.log"
echo "=== VisionClaw Health Check $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG"

ISSUES=0

# 1. Gateway proxy (port 19000)
if curl -s -o /dev/null -w '' --max-time 5 http://localhost:19000/ 2>/dev/null; then
    echo "[OK] Gateway proxy (19000)" >> "$LOG"
else
    echo "[FAIL] Gateway proxy (19000) — not responding" >> "$LOG"
    # Try to restart
    launchctl kickstart -k "gui/$(id -u)/com.isdc.visionclaw-proxy" 2>/dev/null || true
    echo "  → Attempted restart" >> "$LOG"
    ISSUES=$((ISSUES + 1))
fi

# 2. Signaling server (port 8080)
if curl -s -o /dev/null -w '' --max-time 5 http://localhost:8080/ 2>/dev/null; then
    echo "[OK] Signaling server (8080)" >> "$LOG"
else
    echo "[FAIL] Signaling server (8080) — not responding" >> "$LOG"
    launchctl kickstart -k "gui/$(id -u)/com.isdc.visionclaw-signaling" 2>/dev/null || true
    echo "  → Attempted restart" >> "$LOG"
    ISSUES=$((ISSUES + 1))
fi

# 3. OpenClaw gateway (port 18789)
if curl -s -o /dev/null -w '' --max-time 5 http://localhost:18789/ 2>/dev/null; then
    echo "[OK] OpenClaw gateway (18789)" >> "$LOG"
else
    echo "[FAIL] OpenClaw gateway (18789) — not responding" >> "$LOG"
    ISSUES=$((ISSUES + 1))
fi

# 4. ngrok tunnel
TUNNEL_URL=$(curl -s --max-time 5 http://localhost:19000/api/tunnel-url 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('tunnel_url',''))" 2>/dev/null || true)
if [[ -n "$TUNNEL_URL" ]]; then
    TUNNEL_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$TUNNEL_URL/" 2>/dev/null || echo "000")
    if [[ "$TUNNEL_STATUS" == "200" ]]; then
        echo "[OK] ngrok tunnel ($TUNNEL_URL)" >> "$LOG"
    else
        echo "[WARN] ngrok tunnel returned HTTP $TUNNEL_STATUS ($TUNNEL_URL)" >> "$LOG"
        ISSUES=$((ISSUES + 1))
    fi
else
    echo "[FAIL] ngrok tunnel — no URL returned" >> "$LOG"
    launchctl kickstart -k "gui/$(id -u)/com.isdc.ngrok-openclaw" 2>/dev/null || true
    echo "  → Attempted ngrok restart" >> "$LOG"
    ISSUES=$((ISSUES + 1))
fi

# 5. TURN endpoint
if curl -s -o /dev/null -w '' --max-time 5 http://localhost:19000/api/turn 2>/dev/null; then
    echo "[OK] TURN endpoint" >> "$LOG"
else
    echo "[FAIL] TURN endpoint — not responding" >> "$LOG"
    ISSUES=$((ISSUES + 1))
fi

# 6. Dev cert age check
APP_PATH="/Users/isdc/Library/Developer/Xcode/DerivedData/CameraAccess-dvtvpvflmpqsfbfeewfxnwrttfdr/Build/Products/Debug-iphoneos/CameraAccess.app"
if [[ -d "$APP_PATH" ]]; then
    BUILD_EPOCH=$(stat -f %m "$APP_PATH" 2>/dev/null || echo "0")
    NOW_EPOCH=$(date +%s)
    DAYS_OLD=$(( (NOW_EPOCH - BUILD_EPOCH) / 86400 ))
    if [[ "$DAYS_OLD" -ge 6 ]]; then
        echo "[WARN] Dev cert expiring soon — build is ${DAYS_OLD} days old (expires at 7)" >> "$LOG"
        ISSUES=$((ISSUES + 1))
    else
        echo "[OK] Dev cert — build is ${DAYS_OLD} days old" >> "$LOG"
    fi
else
    echo "[WARN] No build found at expected path" >> "$LOG"
fi

# 7. LaunchAgents status
for AGENT in com.isdc.visionclaw-proxy com.isdc.visionclaw-signaling com.isdc.ngrok-openclaw com.isdc.visionclaw-weekly-rebuild; do
    if launchctl list | grep -q "$AGENT"; then
        echo "[OK] LaunchAgent: $AGENT" >> "$LOG"
    else
        echo "[FAIL] LaunchAgent: $AGENT — not loaded" >> "$LOG"
        launchctl load ~/Library/LaunchAgents/${AGENT}.plist 2>/dev/null || true
        echo "  → Attempted load" >> "$LOG"
        ISSUES=$((ISSUES + 1))
    fi
done

# Summary
echo "" >> "$LOG"
if [[ "$ISSUES" -eq 0 ]]; then
    echo "[SUMMARY] All checks passed ✅" >> "$LOG"
else
    echo "[SUMMARY] ${ISSUES} issue(s) found ⚠️" >> "$LOG"
fi
echo "" >> "$LOG"
