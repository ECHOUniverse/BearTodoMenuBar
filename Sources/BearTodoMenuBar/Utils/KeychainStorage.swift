import Foundation
import Security

extension Notification.Name {
    static let bearAPITokenDidChange = Notification.Name("bearAPITokenDidChange")
    static let syncIntervalDidChange = Notification.Name("syncIntervalDidChange")
}

class KeychainStorage {
    static let shared = KeychainStorage()
    private let tokenKey = "bear_api_token"
    private let reminderSyncKey = "bear_reminder_sync_enabled"
    private let launchAtLoginKey = "bear_launch_at_login_enabled"
    private let syncIntervalKey = "bear_sync_interval"
    private let defaults = UserDefaults.standard

    private var didAttemptMigration = false
    private var didMigrateReminderSyncToKeychain = false

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
            // Fast path: already in UserDefaults
            if defaults.object(forKey: reminderSyncKey) != nil {
                let value = defaults.bool(forKey: reminderSyncKey)
                // One-time write to Keychain so it survives app reinstall
                if !didMigrateReminderSyncToKeychain {
                    didMigrateReminderSyncToKeychain = true
                    writeToKeychain(account: reminderSyncKey, value: value ? "true" : "false")
                }
                return value
            }
            // Reinstall path: check Keychain for persisted value
            if let val = readFromKeychain(account: reminderSyncKey) {
                let enabled = (val as NSString).boolValue
                defaults.set(enabled, forKey: reminderSyncKey)
                return enabled
            }
            return false
        }
        set {
            didMigrateReminderSyncToKeychain = true
            defaults.set(newValue, forKey: reminderSyncKey)
            writeToKeychain(account: reminderSyncKey, value: newValue ? "true" : "false")
        }
    }

    var isLaunchAtLoginEnabled: Bool {
        get {
            return defaults.bool(forKey: launchAtLoginKey)
        }
        set {
            defaults.set(newValue, forKey: launchAtLoginKey)
        }
    }

    var syncInterval: Int {
        get {
            if defaults.object(forKey: syncIntervalKey) != nil {
                return defaults.integer(forKey: syncIntervalKey)
            }
            return 0
        }
        set {
            defaults.set(newValue, forKey: syncIntervalKey)
            NotificationCenter.default.post(name: .syncIntervalDidChange, object: nil)
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

    private func writeToKeychain(account: String, value: String) {
        // Remove existing item first, then add new one
        deleteFromKeychain(account: account)
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.beartodo",
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }
}
