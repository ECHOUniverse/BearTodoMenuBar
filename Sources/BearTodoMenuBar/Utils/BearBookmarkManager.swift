import Foundation
import Security

extension Notification.Name {
    static let bearDatabaseAccessGranted = Notification.Name("bearDatabaseAccessGranted")
}

class BearBookmarkManager {
    static let shared = BearBookmarkManager()
    private let bookmarkKey = "bear_database_bookmark"
    private let keychainBookmarkKey = "bear_database_bookmark_keychain"

    var hasBookmark: Bool {
        resolveBookmarkData() != nil
    }

    private var resolvedAccessURL: URL?

    @discardableResult
    func saveBookmark(for url: URL) -> Bool {
        guard url.startAccessingSecurityScopedResource() else {
            return false
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: bookmarkKey)
            writeBookmarkToKeychain(data)
            return true
        } catch {
            print("Failed to save bookmark: \(error)")
            return false
        }
    }

    private func resolveBookmarkData() -> Data? {
        if let data = UserDefaults.standard.data(forKey: bookmarkKey) {
            return data
        }
        if let data = readBookmarkFromKeychain() {
            UserDefaults.standard.set(data, forKey: bookmarkKey)
            return data
        }
        return nil
    }

    func resolveBookmark() -> URL? {
        guard let data = resolveBookmarkData() else {
            return nil
        }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                guard url.startAccessingSecurityScopedResource() else {
                    clearBookmark()
                    return nil
                }
                defer { url.stopAccessingSecurityScopedResource() }
                if let freshData = try? url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                ) {
                    UserDefaults.standard.set(freshData, forKey: bookmarkKey)
                    writeBookmarkToKeychain(freshData)
                    return url
                }
                clearBookmark()
                return nil
            }
            return url
        } catch {
            print("Failed to resolve bookmark: \(error)")
            clearBookmark()
            return nil
        }
    }

    @discardableResult
    func startAccessing() -> Bool {
        if resolvedAccessURL != nil {
            return true
        }
        guard let url = resolveBookmark() else {
            return false
        }
        let success = url.startAccessingSecurityScopedResource()
        if success {
            resolvedAccessURL = url
        }
        return success
    }

    func stopAccessing() {
        guard let url = resolvedAccessURL else { return }
        url.stopAccessingSecurityScopedResource()
        resolvedAccessURL = nil
    }

    private func clearBookmark() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        deleteBookmarkFromKeychain()
    }

    // MARK: - Keychain Backup

    private func readBookmarkFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.beartodo",
            kSecAttrAccount as String: keychainBookmarkKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return data
    }

    private func writeBookmarkToKeychain(_ data: Data) {
        deleteBookmarkFromKeychain()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.beartodo",
            kSecAttrAccount as String: keychainBookmarkKey,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Warning: Failed to write bookmark to Keychain: \(status)")
        }
    }

    private func deleteBookmarkFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.beartodo",
            kSecAttrAccount as String: keychainBookmarkKey
        ]
        SecItemDelete(query as CFDictionary)
    }
}
