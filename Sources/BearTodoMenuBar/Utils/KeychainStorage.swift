import Foundation

extension Notification.Name {
    static let bearAPITokenDidChange = Notification.Name("bearAPITokenDidChange")
}

class KeychainStorage {
    static let shared = KeychainStorage()
    private let tokenKey = "bear_api_token"
    private let defaults = UserDefaults.standard

    var token: String? {
        get {
            return defaults.string(forKey: tokenKey)
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
        if let t = token {
            return !t.isEmpty
        }
        return false
    }

    func clearToken() {
        defaults.removeObject(forKey: tokenKey)
        NotificationCenter.default.post(name: .bearAPITokenDidChange, object: nil)
    }
}
