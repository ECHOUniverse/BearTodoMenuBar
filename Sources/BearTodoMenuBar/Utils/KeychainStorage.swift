import Foundation
import Security

extension Notification.Name {
    static let bearAPITokenDidChange = Notification.Name("bearAPITokenDidChange")
}

class KeychainStorage {
    static let shared = KeychainStorage()
    private let tokenKey = "bear_api_token"
    private let service = "com.beartodo.menubar"

    var token: String? {
        get {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: tokenKey,
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
        set {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: tokenKey
            ]

            SecItemDelete(query as CFDictionary)

            guard let value = newValue, !value.isEmpty,
                  let data = value.data(using: .utf8) else {
                NotificationCenter.default.post(name: .bearAPITokenDidChange, object: nil)
                return
            }

            let attributes: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: tokenKey,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
            ]

            SecItemAdd(attributes as CFDictionary, nil)
            NotificationCenter.default.post(name: .bearAPITokenDidChange, object: nil)
        }
    }

    var hasToken: Bool {
        token != nil && !token!.isEmpty
    }
}
