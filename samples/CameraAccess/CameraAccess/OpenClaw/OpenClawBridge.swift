import Foundation
import UIKit

enum OpenClawConnectionState: Equatable {
  case notConfigured
  case checking
  case connected
  case connectedViaTunnel
  case unreachable(String)
}

@MainActor
class OpenClawBridge: ObservableObject {
  @Published var lastToolCallStatus: ToolCallStatus = .idle
  @Published var connectionState: OpenClawConnectionState = .notConfigured

  private let session: URLSession
  private let pingSession: URLSession
  private var sessionKey: String
  private var conversationHistory: [[String: String]] = []
  private let maxHistoryTurns = 10
  /// Tracks whether we should prefer the tunnel URL (set when LAN fails and tunnel succeeds)
  private var preferTunnel = false
  /// Health check timer
  private var healthCheckTask: Task<Void, Never>?
  /// Track consecutive failures for escalation
  private var consecutiveFailures = 0

  private let network = NetworkMonitor.shared

  init() {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 120
    self.session = URLSession(configuration: config)

    let pingConfig = URLSessionConfiguration.default
    pingConfig.timeoutIntervalForRequest = 8 // 8s — generous for 5G→ngrok round trips
    self.pingSession = URLSession(configuration: pingConfig)

    self.sessionKey = OpenClawBridge.newSessionKey()

    // React to network changes (WiFi ↔ cellular)
    network.onNetworkChange = { [weak self] newType in
      guard let self else { return }
      Task { @MainActor in
        NSLog("[OpenClaw] Network changed to %@ — re-checking connection", newType.rawValue)
        // On cellular, force tunnel preference immediately
        if newType == .cellular {
          self.preferTunnel = true
        } else if newType == .wifi {
          // On WiFi, try LAN first again
          self.preferTunnel = false
        }
        await self.checkConnection()
      }
    }
  }

  // MARK: - URL helpers

  /// Primary LAN URL (e.g. http://ISDCs-Mac-mini.local:18789)
  private var lanBaseURL: String {
    "\(GeminiConfig.openClawHost):\(GeminiConfig.openClawPort)"
  }

  /// Tunnel URL (e.g. https://xxx.ngrok-free.dev) — no port needed, tunnel handles routing
  private var tunnelBaseURL: String? {
    let url = GeminiConfig.openClawTunnelURL
    guard !url.isEmpty else { return nil }
    return url
  }

  /// Returns the best URL based on network type and preferences.
  /// On cellular: always use tunnel (LAN/mDNS can't work).
  /// On WiFi: use LAN unless we've learned it's down and tunnel works.
  private var activeBaseURL: String {
    // On cellular, mDNS doesn't work — tunnel is the only option
    if network.isCellular, let tunnel = tunnelBaseURL {
      return tunnel
    }
    if preferTunnel, let tunnel = tunnelBaseURL {
      return tunnel
    }
    return lanBaseURL
  }

  private func chatURL(base: String) -> URL? {
    URL(string: "\(base)/v1/chat/completions")
  }

  private func buildRequest(url: URL, method: String = "POST") -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("Bearer \(GeminiConfig.openClawGatewayToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(sessionKey, forHTTPHeaderField: "x-openclaw-session-key")
    // Skip ngrok browser warning interstitial
    request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
    return request
  }

  // MARK: - Tunnel URL auto-discovery

  /// On WiFi, fetches the current ngrok URL from the proxy's /api/tunnel-url endpoint.
  /// This handles the case where ngrok restarts with a new URL after Mac reboot.
  private func discoverTunnelURL() async {
    guard network.isWiFi else { return }
    let discoveryURL = "\(lanBaseURL)/api/tunnel-url"
    guard let url = URL(string: discoveryURL) else { return }

    do {
      var request = URLRequest(url: url)
      request.timeoutInterval = 3
      let (data, response) = try await pingSession.data(for: request)
      guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
      // Verify response is JSON, not HTML (the web UI serves HTML on unknown paths)
      guard let contentType = http.value(forHTTPHeaderField: "Content-Type"),
            contentType.contains("json") else {
        return
      }
      if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
         let tunnelURL = json["tunnel_url"] as? String, !tunnelURL.isEmpty {
        let current = SettingsManager.shared.openClawTunnelURL
        if current != tunnelURL {
          NSLog("[OpenClaw] Tunnel URL updated: %@ → %@", current, tunnelURL)
          SettingsManager.shared.openClawTunnelURL = tunnelURL
        }
      }
    } catch {
      // Expected to fail if /api/tunnel-url endpoint doesn't exist — suppress log
    }
  }

  // MARK: - Connection check with network-aware fallback

  func checkConnection() async {
    guard GeminiConfig.isOpenClawConfigured else {
      connectionState = .notConfigured
      return
    }
    connectionState = .checking

    // On WiFi, auto-discover the latest tunnel URL (handles ngrok restarts)
    await discoverTunnelURL()

    // On cellular, skip LAN entirely — mDNS won't resolve
    if network.isCellular {
      NSLog("[OpenClaw] On cellular — skipping LAN, trying tunnel only")
      if let tunnel = tunnelBaseURL, let url = chatURL(base: tunnel) {
        // Try up to 2 times on cellular (first attempt may be slow due to ngrok cold start)
        for attempt in 1...2 {
          if await ping(url: url) {
            preferTunnel = true
            connectionState = .connectedViaTunnel
            consecutiveFailures = 0
            NSLog("[OpenClaw] Gateway reachable via tunnel (cellular, attempt %d)", attempt)
            return
          }
          if attempt < 2 {
            NSLog("[OpenClaw] Tunnel ping attempt %d failed, retrying...", attempt)
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s before retry
          }
        }
      }
      preferTunnel = true // Keep preference for when tunnel comes back
      connectionState = .unreachable("Tunnel unreachable on cellular. Check ngrok is running on Mac.")
      NSLog("[OpenClaw] Tunnel unreachable on cellular after retries")
      return
    }

    // On WiFi: try LAN first (faster), then tunnel fallback
    if let url = chatURL(base: lanBaseURL), await ping(url: url) {
      preferTunnel = false
      connectionState = .connected
      consecutiveFailures = 0
      NSLog("[OpenClaw] Gateway reachable via LAN")
      return
    }

    // LAN failed on WiFi — try tunnel
    if let tunnel = tunnelBaseURL, let url = chatURL(base: tunnel), await ping(url: url) {
      preferTunnel = true
      connectionState = .connectedViaTunnel
      consecutiveFailures = 0
      NSLog("[OpenClaw] LAN failed, gateway reachable via tunnel")
      return
    }

    preferTunnel = false
    connectionState = .unreachable("LAN and tunnel both unreachable")
    NSLog("[OpenClaw] Gateway unreachable on both LAN and tunnel")
  }

  private func ping(url: URL, retries: Int = 1) async -> Bool {
    for attempt in 0...retries {
      var request = URLRequest(url: url)
      request.httpMethod = "GET"
      request.setValue("Bearer \(GeminiConfig.openClawGatewayToken)", forHTTPHeaderField: "Authorization")
      request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
      do {
        let (_, response) = try await pingSession.data(for: request)
        if let http = response as? HTTPURLResponse, (200...499).contains(http.statusCode) {
          return true
        }
      } catch {}
      if attempt < retries {
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s before retry
      }
    }
    return false
  }

  // MARK: - Health check (periodic, runs during active sessions)

  func startHealthCheck() {
    stopHealthCheck()
    healthCheckTask = Task { [weak self] in
      // First check after 5s (fast initial feedback), then every 30s
      try? await Task.sleep(nanoseconds: 5_000_000_000)
      guard !Task.isCancelled else { return }
      guard let strongSelf = self else { return }
      await strongSelf.checkConnection()

      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 30_000_000_000)
        guard !Task.isCancelled else { break }
        guard let strongSelf = self else { break }
        // Only re-check if we're not mid-request
        if case .executing = strongSelf.lastToolCallStatus { continue }
        await strongSelf.checkConnection()
      }
    }
    NSLog("[OpenClaw] Health check started (5s initial, 30s interval)")
  }

  func stopHealthCheck() {
    healthCheckTask?.cancel()
    healthCheckTask = nil
  }

  func resetSession() {
    sessionKey = OpenClawBridge.newSessionKey()
    conversationHistory = []
    consecutiveFailures = 0
    NSLog("[OpenClaw] New session: %@", sessionKey)
  }

  private static func newSessionKey() -> String {
    let ts = ISO8601DateFormatter().string(from: Date())
    return "agent:main:glass:\(ts)"
  }

  // MARK: - Agent Chat (session continuity via x-openclaw-session-key header)

  func delegateTask(
    task: String,
    toolName: String = "execute"
  ) async -> ToolResult {
    lastToolCallStatus = .executing(toolName)

    guard let url = chatURL(base: activeBaseURL) else {
      lastToolCallStatus = .failed(toolName, "Invalid URL")
      return .failure("Invalid gateway URL")
    }

    // Append the new user message to conversation history
    conversationHistory.append(["role": "user", "content": task])

    // Trim history to keep only the most recent turns (user+assistant pairs)
    if conversationHistory.count > maxHistoryTurns * 2 {
      conversationHistory = Array(conversationHistory.suffix(maxHistoryTurns * 2))
    }

    var request = buildRequest(url: url)

    let body: [String: Any] = [
      "model": "openclaw",
      "messages": conversationHistory,
      "stream": false
    ]

    let via = network.isCellular ? "tunnel (cellular)" : (preferTunnel ? "tunnel" : "LAN")
    NSLog("[OpenClaw] Sending %d messages via %@", conversationHistory.count, via)

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: body)
      let result = try await sendRequest(request, body: request.httpBody!)
      switch result {
      case .success(let content):
        conversationHistory.append(["role": "assistant", "content": content])
        NSLog("[OpenClaw] Agent result: %@", String(content.prefix(200)))
        lastToolCallStatus = .completed(toolName)
        consecutiveFailures = 0
        return .success(content)
      case .failure(let error):
        return await handleFailureWithFallback(
          error: error,
          body: body,
          toolName: toolName,
          originalRequest: request
        )
      }
    } catch {
      return await handleNetworkError(
        error: error,
        body: body,
        toolName: toolName
      )
    }
  }

  /// Handles a non-2xx response by trying the fallback path.
  private func handleFailureWithFallback(
    error: String,
    body: [String: Any],
    toolName: String,
    originalRequest: URLRequest
  ) async -> ToolResult {
    consecutiveFailures += 1

    // Try the opposite path: if we were on LAN, try tunnel; if on tunnel, try LAN (WiFi only)
    let fallbackURL: URL?
    let fallbackLabel: String

    if preferTunnel || network.isCellular {
      // We were on tunnel and it failed. On WiFi, try LAN.
      if !network.isCellular, let url = chatURL(base: lanBaseURL) {
        fallbackURL = url
        fallbackLabel = "LAN"
      } else {
        fallbackURL = nil
        fallbackLabel = ""
      }
    } else {
      // We were on LAN and it failed. Try tunnel.
      if let tunnel = tunnelBaseURL, let url = chatURL(base: tunnel) {
        fallbackURL = url
        fallbackLabel = "tunnel"
      } else {
        fallbackURL = nil
        fallbackLabel = ""
      }
    }

    if let fallbackURL {
      NSLog("[OpenClaw] Primary failed, trying %@ fallback...", fallbackLabel)
      do {
        var fallbackRequest = buildRequest(url: fallbackURL)
        fallbackRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        let fallbackResult = try await sendRequest(fallbackRequest, body: fallbackRequest.httpBody!)
        switch fallbackResult {
        case .success(let content):
          preferTunnel = fallbackLabel == "tunnel"
          connectionState = preferTunnel ? .connectedViaTunnel : .connected
          conversationHistory.append(["role": "assistant", "content": content])
          NSLog("[OpenClaw] %@ fallback succeeded, switching", fallbackLabel)
          lastToolCallStatus = .completed(toolName)
          consecutiveFailures = 0
          return .success(content)
        case .failure:
          break
        }
      } catch {}
    }

    lastToolCallStatus = .failed(toolName, error)
    return .failure(error)
  }

  /// Handles a network-level error (timeout, DNS, etc.) by trying the fallback path.
  private func handleNetworkError(
    error: Error,
    body: [String: Any],
    toolName: String
  ) async -> ToolResult {
    consecutiveFailures += 1
    NSLog("[OpenClaw] Network error: %@", error.localizedDescription)

    // On cellular, if tunnel fails there's nothing else to try
    if network.isCellular {
      lastToolCallStatus = .failed(toolName, "Tunnel unreachable on cellular")
      connectionState = .unreachable("Tunnel unreachable on cellular")
      return .failure("OpenClaw unreachable on cellular. Check tunnel is running on Mac.")
    }

    // On WiFi, try the other path
    let fallbackBase: String?
    let fallbackLabel: String

    if preferTunnel {
      fallbackBase = lanBaseURL
      fallbackLabel = "LAN"
    } else if let tunnel = tunnelBaseURL {
      fallbackBase = tunnel
      fallbackLabel = "tunnel"
    } else {
      fallbackBase = nil
      fallbackLabel = ""
    }

    if let fallbackBase, let fallbackURL = chatURL(base: fallbackBase) {
      NSLog("[OpenClaw] Network error, trying %@ fallback...", fallbackLabel)
      do {
        var fallbackRequest = buildRequest(url: fallbackURL)
        fallbackRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        let fallbackResult = try await sendRequest(fallbackRequest, body: fallbackRequest.httpBody!)
        switch fallbackResult {
        case .success(let content):
          preferTunnel = fallbackLabel == "tunnel"
          connectionState = preferTunnel ? .connectedViaTunnel : .connected
          conversationHistory.append(["role": "assistant", "content": content])
          NSLog("[OpenClaw] %@ fallback succeeded", fallbackLabel)
          lastToolCallStatus = .completed(toolName)
          consecutiveFailures = 0
          return .success(content)
        case .failure:
          break
        }
      } catch {}
    }

    lastToolCallStatus = .failed(toolName, error.localizedDescription)
    return .failure("Agent error: \(error.localizedDescription)")
  }

  private func sendRequest(_ request: URLRequest, body: Data) async throws -> ToolResult {
    let (data, response) = try await session.data(for: request)
    let httpResponse = response as? HTTPURLResponse

    guard let statusCode = httpResponse?.statusCode, (200...299).contains(statusCode) else {
      let code = httpResponse?.statusCode ?? 0
      let bodyStr = String(data: data, encoding: .utf8) ?? "no body"
      NSLog("[OpenClaw] Chat failed: HTTP %d - %@", code, String(bodyStr.prefix(200)))
      return .failure("Agent returned HTTP \(code)")
    }

    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let choices = json["choices"] as? [[String: Any]],
       let first = choices.first,
       let message = first["message"] as? [String: Any],
       let content = message["content"] as? String {
      return .success(content)
    }

    let raw = String(data: data, encoding: .utf8) ?? "OK"
    return .success(raw)
  }

  // MARK: - Image Upload via Task (base64 inline)

  func delegateTaskWithImage(
    task: String,
    image: UIImage,
    toolName: String = "capture_and_send"
  ) async -> ToolResult {
    lastToolCallStatus = .executing(toolName)

    guard let jpegData = image.jpegData(compressionQuality: 0.7) else {
      lastToolCallStatus = .failed(toolName, "JPEG conversion failed")
      return .failure("Failed to convert image to JPEG")
    }

    let base64 = jpegData.base64EncodedString()
    let sizeKB = jpegData.count / 1024
    NSLog("[OpenClaw] Image captured: %dKB JPEG, base64 length: %d", sizeKB, base64.count)

    let fullTask = """
    \(task)

    ATTACHED IMAGE (base64 JPEG — save to a temp file first, then send it):
    \(base64)
    """

    return await delegateTask(task: fullTask, toolName: toolName)
  }
}
