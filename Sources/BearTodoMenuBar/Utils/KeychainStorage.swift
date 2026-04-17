import Foundation
import Security

extension Notification.Name {
    static let bearAPITokenDidChange = Notification.Name("bearAPITokenDidChange")
}

class KeychainStorage {
    static let shared = KeychainStorage()
    private let service = "com.beartodo"
    private let tokenAccount = "bear_api_token"
    private let reminderSyncKey = "bear_reminder_sync_enabled"
    private let defaults = UserDefaults.standard

    private var cachedToken: String?
    private var didLoadToken = false

    var token: String? {
        get {
            if didLoadToken { return cachedToken }
            cachedToken = readFromKeychain(account: tokenAccount)
            didLoadToken = true
            return cachedToken
        }
        set {
            cachedToken = newValue
            didLoadToken = true
            if let value = newValue, !value.isEmpty {
                _ = saveToKeychain(value, account: tokenAccount)
            } else {
                deleteFromKeychain(account: tokenAccount)
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
        cachedToken = nil
        didLoadToken = true
        deleteFromKeychain(account: tokenAccount)
        NotificationCenter.default.post(name: .bearAPITokenDidChange, object: nil)
    }

    // MARK: - Keychain Helpers

    private func saveToKeychain(_ value: String, account: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func readFromKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
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
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
