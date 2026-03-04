import Foundation

enum DiscordWebhookService {

  struct SessionSummary {
    let mode: SessionMode
    let streamingMode: StreamingMode
    let startTime: Date?
    let durationSeconds: Int
    let sessionLog: [(timestamp: Date, role: String, text: String)]
    let meetingLines: [MeetingLine]
    let golfState: GolfState?
    let translationLines: [TranslationLine]
  }

  static func post(summary: SessionSummary) async -> Bool {
    let webhookURL = SettingsManager.shared.discordVisionClawWebhook
    guard !webhookURL.isEmpty, let url = URL(string: webhookURL) else {
      NSLog("[Discord] No webhook URL configured")
      return false
    }

    let embed = buildEmbed(from: summary)
    let payload: [String: Any] = [
      "username": "VisionClaw",
      "embeds": [embed]
    ]

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 15

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: payload)
      let (_, response) = try await URLSession.shared.data(for: request)
      if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
        NSLog("[Discord] Session notes posted successfully")
        return true
      } else {
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        NSLog("[Discord] Webhook returned HTTP %d", code)
        return false
      }
    } catch {
      NSLog("[Discord] Webhook error: %@", error.localizedDescription)
      return false
    }
  }

  // MARK: - Embed Builder

  private static func buildEmbed(from summary: SessionSummary) -> [String: Any] {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd HH:mm"
    let dateStr = summary.startTime.map { df.string(from: $0) } ?? "Unknown"
    let minutes = summary.durationSeconds / 60
    let seconds = summary.durationSeconds % 60

    let (title, color, description) = contentForMode(summary)

    let embed: [String: Any] = [
      "title": title,
      "color": color,
      "description": truncate(description, maxLength: 4000),
      "footer": ["text": "VisionClaw | \(dateStr) | \(minutes)m \(seconds)s"],
      "timestamp": ISO8601DateFormatter().string(from: Date())
    ]
    return embed
  }

  private static func contentForMode(_ s: SessionSummary) -> (String, Int, String) {
    switch s.mode {
    case .meeting:         return buildMeetingContent(s)
    case .golf:            return buildGolfContent(s)
    case .liveTranslation: return buildTranslationContent(s)
    case .normal:          return buildNormalContent(s)
    }
  }

  private static func buildMeetingContent(_ s: SessionSummary) -> (String, Int, String) {
    let tf = DateFormatter()
    tf.dateFormat = "HH:mm"
    var lines: [String] = []
    for line in s.meetingLines {
      let time = tf.string(from: line.time)
      let icon = line.speaker == "Notes" ? "**[Notes]**" : "**\(line.speaker)**"
      lines.append("`\(time)` \(icon) \(line.text)")
    }
    if lines.isEmpty {
      lines = consolidatedLog(s.sessionLog).map { "**\($0.role):** \($0.text)" }
    }
    return ("Meeting Notes", 0xFFA500, lines.joined(separator: "\n"))
  }

  private static func buildGolfContent(_ s: SessionSummary) -> (String, Int, String) {
    let courseName = s.golfState?.courseName ?? ""
    let title = "Golf Round" + (courseName.isEmpty ? "" : " - \(courseName)")
    var lines: [String] = []
    if let state = s.golfState {
      let parStr = state.scoreToPar >= 0 ? "+\(state.scoreToPar)" : "\(state.scoreToPar)"
      lines.append("**Hole:** \(state.currentHole) | **Score:** \(state.totalScore) | **To Par:** \(parStr)")
      lines.append("")
    }
    let entries = consolidatedLog(s.sessionLog)
    for entry in entries.suffix(30) {
      lines.append("**\(entry.role):** \(entry.text)")
    }
    return (title, 0x00CC00, lines.joined(separator: "\n"))
  }

  private static func buildTranslationContent(_ s: SessionSummary) -> (String, Int, String) {
    let tf = DateFormatter()
    tf.dateFormat = "HH:mm"
    var lines: [String] = []
    for line in s.translationLines {
      let time = tf.string(from: line.time)
      let prefix = line.isTranslation ? "->" : ":"
      lines.append("`\(time)` \(prefix) \(line.text)")
    }
    if lines.isEmpty {
      lines = consolidatedLog(s.sessionLog).map { "**\($0.role):** \($0.text)" }
    }
    return ("Translation Session", 0x3498DB, lines.joined(separator: "\n"))
  }

  private static func buildNormalContent(_ s: SessionSummary) -> (String, Int, String) {
    let modeLabel = s.streamingMode == .iPhone ? "iPhone" : "Glasses"
    var lines: [String] = []
    let entries = consolidatedLog(s.sessionLog)
    for entry in entries {
      lines.append("**\(entry.role):** \(entry.text)")
    }
    return ("Session (\(modeLabel))", 0x9B59B6, lines.joined(separator: "\n"))
  }

  // MARK: - Helpers

  private static func consolidatedLog(
    _ log: [(timestamp: Date, role: String, text: String)]
  ) -> [(role: String, text: String)] {
    var result: [(role: String, text: String)] = []
    for entry in log {
      if let last = result.last, last.role == entry.role {
        result[result.count - 1].text += " " + entry.text
      } else {
        result.append((role: entry.role, text: entry.text))
      }
    }
    return result
  }

  private static func truncate(_ text: String, maxLength: Int) -> String {
    guard text.count > maxLength else { return text }
    let cutoff = text.index(text.startIndex, offsetBy: maxLength - 20)
    return String(text[..<cutoff]) + "\n\n... [truncated]"
  }
}
