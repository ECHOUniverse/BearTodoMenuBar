import Foundation
import Security

extension Notification.Name {
    static let bearAPITokenDidChange = Notification.Name("bearAPITokenDidChange")
}

class KeychainStorage {
    static let shared = KeychainStorage()
    private let tokenKey = "bear_api_token"
    private let reminderSyncKey = "bear_reminder_sync_enabled"
    private let defaults = UserDefaults.standard

    private var didAttemptMigration = false

    var token: String? {
        get {
            // Fast path: already stored in UserDefaults
            if let value = defaults.string(forKey: tokenKey), !value.isEmpty {
                return value
            }

            // One-time migration from keychain
            if !didAttemptMigration {
                didAttemptMigration = true
                if let keychainValue = readFromKeychain(account: tokenKey),
                   !keychainValue.isEmpty {
                    defaults.set(keychainValue, forKey: tokenKey)
                    deleteFromKeychain(account: tokenKey)
                    return keychainValue
                }
            }

            return nil
        }
        set {
            if let value = newValue, !value.isEmpty {
                defaults.set(value, forKey: tokenKey)
            } else {
                defaults.removeObject(forKey: tokenKey)
            }
            NotificationCenter.default.post(name: .bearAPITokenDidChange, object: nil)
        }
    }

    var hasToken: Bool {
        guard let t = token else { return false }
        return !t.isEmpty
    }

    var isReminderSyncEnabled: Bool {
        get {
            return defaults.bool(forKey: reminderSyncKey)
        }
        set {
            defaults.set(newValue, forKey: reminderSyncKey)
        }
    }

    func clearToken() {
        defaults.removeObject(forKey: tokenKey)
        deleteFromKeychain(account: tokenKey)
        NotificationCenter.default.post(name: .bearAPITokenDidChange, object: nil)
    }

    // MARK: - Keychain Helpers (one-time migration)

    private func readFromKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.beartodo",
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    private func deleteFromKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.beartodo",
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
