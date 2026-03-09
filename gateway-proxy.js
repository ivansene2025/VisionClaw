#!/usr/bin/env node
// Unified Gateway Proxy for VisionClaw
// Routes through a single ngrok tunnel:
//   - WebSocket connections → Signaling server (port 8080)
//   - HTTP requests → OpenClaw gateway (port 18789)
//
// This allows one ngrok URL to handle everything.

const http = require("http");
const net = require("net");

const PROXY_PORT = parseInt(process.env.PROXY_PORT || "19000");
const OPENCLAW_PORT = parseInt(process.env.OPENCLAW_PORT || "18789");
const SIGNALING_PORT = parseInt(process.env.SIGNALING_PORT || "8080");
const OPENCLAW_HOST = process.env.OPENCLAW_HOST || "127.0.0.1";
const SIGNALING_HOST = process.env.SIGNALING_HOST || "127.0.0.1";

// Paths that should go to the signaling server (HTTP, not WS)
const SIGNALING_PATHS = ["/api/turn"];

// Cache ngrok URL (refreshed every 60s)
let cachedNgrokURL = null;
let lastNgrokCheck = 0;

async function getNgrokURL() {
  const now = Date.now();
  if (cachedNgrokURL && now - lastNgrokCheck < 60000) return cachedNgrokURL;
  try {
    const res = await fetch("http://localhost:4040/api/tunnels");
    const data = await res.json();
    const tunnel = data.tunnels?.[0];
    if (tunnel) {
      cachedNgrokURL = tunnel.public_url;
      lastNgrokCheck = now;
    }
  } catch {}
  return cachedNgrokURL;
}

// HTTP requests → route based on path
const server = http.createServer(async (req, res) => {
  // Auto-discovery endpoint: returns current ngrok tunnel URL
  // iOS app calls this over LAN to learn the tunnel URL for 5G use
  if (req.url === "/api/tunnel-url") {
    const url = await getNgrokURL();
    res.writeHead(200, {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    });
    res.end(JSON.stringify({ tunnel_url: url || null }));
    return;
  }

  const isSignalingPath = SIGNALING_PATHS.some((p) => req.url.startsWith(p));
  const targetHost = isSignalingPath ? SIGNALING_HOST : OPENCLAW_HOST;
  const targetPort = isSignalingPath ? SIGNALING_PORT : OPENCLAW_PORT;
  const targetLabel = isSignalingPath ? "Signaling" : "OpenClaw";

  const proxyReq = http.request(
    {
      hostname: targetHost,
      port: targetPort,
      path: req.url,
      method: req.method,
      headers: req.headers,
    },
    (proxyRes) => {
      res.writeHead(proxyRes.statusCode, proxyRes.headers);
      proxyRes.pipe(res);
    }
  );

  proxyReq.on("error", (err) => {
    console.error(`[Proxy] ${targetLabel} error: ${err.message}`);
    res.writeHead(502, { "Content-Type": "text/plain" });
    res.end(`${targetLabel} unreachable`);
  });

  req.pipe(proxyReq);
});

// WebSocket upgrade → Signaling server
server.on("upgrade", (req, socket, head) => {
  console.log(`[Proxy] WebSocket upgrade → signaling (${req.url})`);

  const proxySocket = net.connect(SIGNALING_PORT, SIGNALING_HOST, () => {
    // Reconstruct the HTTP upgrade request to forward to signaling server
    const headers = [`${req.method} ${req.url} HTTP/1.1`];
    for (let i = 0; i < req.rawHeaders.length; i += 2) {
      headers.push(`${req.rawHeaders[i]}: ${req.rawHeaders[i + 1]}`);
    }
    headers.push("", "");

    proxySocket.write(headers.join("\r\n"));
    if (head && head.length) {
      proxySocket.write(head);
    }

    // Bidirectional pipe
    proxySocket.pipe(socket);
    socket.pipe(proxySocket);
  });

  proxySocket.on("error", (err) => {
    console.error(`[Proxy] Signaling error: ${err.message}`);
    socket.end();
  });

  socket.on("error", (err) => {
    console.error(`[Proxy] Client socket error: ${err.message}`);
    proxySocket.end();
  });
});

server.listen(PROXY_PORT, "0.0.0.0", () => {
  console.log(`[Proxy] Unified gateway running on port ${PROXY_PORT}`);
  console.log(`[Proxy]   HTTP → OpenClaw (${OPENCLAW_HOST}:${OPENCLAW_PORT})`);
  console.log(`[Proxy]   WS   → Signaling (${SIGNALING_HOST}:${SIGNALING_PORT})`);
});
