import Foundation
import Security

/// Lightweight Keychain wrapper for storing sensitive strings (API keys, tokens).
/// Uses kSecClassGenericPassword with a service prefix to namespace items.
enum KeychainHelper {
  private static let service = "com.kikinhochow.VisionClaw"

  static func set(_ value: String, forKey key: String) {
    guard let data = value.data(using: .utf8) else { return }

    // Delete any existing item first
    let deleteQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
    ]
    SecItemDelete(deleteQuery as CFDictionary)

    // Don't store empty strings
    guard !value.isEmpty else { return }

    let addQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
    ]
    let status = SecItemAdd(addQuery as CFDictionary, nil)
    if status != errSecSuccess && status != errSecDuplicateItem {
      NSLog("[Keychain] Write failed for %@: %d", key, status)
    }
  }

  static func get(forKey key: String) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess, let data = result as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  static func delete(forKey key: String) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
    ]
    SecItemDelete(query as CFDictionary)
  }

  static func deleteAll() {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
    ]
    SecItemDelete(query as CFDictionary)
  }
}
