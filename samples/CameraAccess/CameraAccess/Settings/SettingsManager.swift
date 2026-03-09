import Foundation

final class SettingsManager {
  static let shared = SettingsManager()

  private let defaults = UserDefaults.standard

  // Non-sensitive keys stored in UserDefaults
  private enum Key: String {
    case openClawHost
    case openClawPort
    case geminiSystemPrompt
    case translationTargetLanguage
    case translationOutputMode
    case golfSevenIronCarry
    case webrtcSignalingURL
  }

  // Sensitive keys stored in Keychain
  private enum SecureKey: String {
    case geminiAPIKey
    case openClawHookToken
    case openClawGatewayToken
    case openClawTunnelURL
    case golfCourseAPIKey
    case discordVisionClawWebhook
  }

  private init() {
    migrateFromUserDefaultsIfNeeded()
  }

  // MARK: - One-time migration from UserDefaults → Keychain

  private func migrateFromUserDefaultsIfNeeded() {
    let migrationKey = "keychain_migration_v1"
    guard !defaults.bool(forKey: migrationKey) else { return }

    // Migrate each sensitive field: read from UserDefaults, write to Keychain, delete from UserDefaults
    let keysToMigrate: [(udKey: String, secKey: SecureKey)] = [
      ("geminiAPIKey", .geminiAPIKey),
      ("openClawHookToken", .openClawHookToken),
      ("openClawGatewayToken", .openClawGatewayToken),
      ("openClawTunnelURL", .openClawTunnelURL),
      ("golfCourseAPIKey", .golfCourseAPIKey),
      ("discordVisionClawWebhook", .discordVisionClawWebhook),
    ]
    for (udKey, secKey) in keysToMigrate {
      if let value = defaults.string(forKey: udKey), !value.isEmpty {
        KeychainHelper.set(value, forKey: secKey.rawValue)
        defaults.removeObject(forKey: udKey)
        NSLog("[Settings] Migrated %@ from UserDefaults to Keychain", udKey)
      }
    }
    defaults.set(true, forKey: migrationKey)
  }

  // MARK: - Secure getters/setters (Keychain-backed)

  var geminiAPIKey: String {
    get { KeychainHelper.get(forKey: SecureKey.geminiAPIKey.rawValue) ?? Secrets.geminiAPIKey }
    set { KeychainHelper.set(newValue, forKey: SecureKey.geminiAPIKey.rawValue) }
  }

  var openClawHookToken: String {
    get { KeychainHelper.get(forKey: SecureKey.openClawHookToken.rawValue) ?? Secrets.openClawHookToken }
    set { KeychainHelper.set(newValue, forKey: SecureKey.openClawHookToken.rawValue) }
  }

  var openClawGatewayToken: String {
    get { KeychainHelper.get(forKey: SecureKey.openClawGatewayToken.rawValue) ?? Secrets.openClawGatewayToken }
    set { KeychainHelper.set(newValue, forKey: SecureKey.openClawGatewayToken.rawValue) }
  }

  var openClawTunnelURL: String {
    get { KeychainHelper.get(forKey: SecureKey.openClawTunnelURL.rawValue) ?? Secrets.openClawTunnelURL }
    set { KeychainHelper.set(newValue, forKey: SecureKey.openClawTunnelURL.rawValue) }
  }

  var golfCourseAPIKey: String {
    get { KeychainHelper.get(forKey: SecureKey.golfCourseAPIKey.rawValue) ?? "" }
    set { KeychainHelper.set(newValue, forKey: SecureKey.golfCourseAPIKey.rawValue) }
  }

  var discordVisionClawWebhook: String {
    get { KeychainHelper.get(forKey: SecureKey.discordVisionClawWebhook.rawValue) ?? "" }
    set { KeychainHelper.set(newValue, forKey: SecureKey.discordVisionClawWebhook.rawValue) }
  }

  // MARK: - Non-sensitive (UserDefaults-backed)

  var geminiSystemPrompt: String {
    get { defaults.string(forKey: Key.geminiSystemPrompt.rawValue) ?? GeminiConfig.defaultSystemInstruction }
    set { defaults.set(newValue, forKey: Key.geminiSystemPrompt.rawValue) }
  }

  var openClawHost: String {
    get { defaults.string(forKey: Key.openClawHost.rawValue) ?? Secrets.openClawHost }
    set { defaults.set(newValue, forKey: Key.openClawHost.rawValue) }
  }

  var openClawPort: Int {
    get {
      let stored = defaults.integer(forKey: Key.openClawPort.rawValue)
      return stored != 0 ? stored : Secrets.openClawPort
    }
    set { defaults.set(newValue, forKey: Key.openClawPort.rawValue) }
  }

  var webrtcSignalingURL: String {
    get { defaults.string(forKey: Key.webrtcSignalingURL.rawValue) ?? Secrets.webrtcSignalingURL }
    set { defaults.set(newValue, forKey: Key.webrtcSignalingURL.rawValue) }
  }

  var translationTargetLanguage: String {
    get { defaults.string(forKey: Key.translationTargetLanguage.rawValue) ?? "English" }
    set { defaults.set(newValue, forKey: Key.translationTargetLanguage.rawValue) }
  }

  var translationOutputMode: String {
    get { defaults.string(forKey: Key.translationOutputMode.rawValue) ?? "both" }
    set { defaults.set(newValue, forKey: Key.translationOutputMode.rawValue) }
  }

  var golfSevenIronCarry: Int {
    get {
      let stored = defaults.integer(forKey: Key.golfSevenIronCarry.rawValue)
      return stored > 0 ? stored : 140
    }
    set { defaults.set(newValue, forKey: Key.golfSevenIronCarry.rawValue) }
  }

  // MARK: - Reset

  func resetAll() {
    // Clear UserDefaults
    for key in [Key.geminiSystemPrompt, .openClawHost, .openClawPort,
                .webrtcSignalingURL, .translationTargetLanguage,
                .translationOutputMode, .golfSevenIronCarry] {
      defaults.removeObject(forKey: key.rawValue)
    }
    // Clear Keychain
    KeychainHelper.deleteAll()
  }
}
