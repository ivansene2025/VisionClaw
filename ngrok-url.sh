#!/bin/bash
# Gets the current ngrok tunnel URL for OpenClaw gateway
URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); tunnels=d.get('tunnels',[]); [print(t['public_url']) for t in tunnels]" 2>/dev/null)
if [ -z "$URL" ]; then
  echo "ngrok not running. Start it: launchctl load ~/Library/LaunchAgents/com.isdc.ngrok-openclaw.plist"
  exit 1
fi
echo "Current ngrok URL: $URL"
echo "Set this in VisionClaw app > Settings > Tunnel URL"
