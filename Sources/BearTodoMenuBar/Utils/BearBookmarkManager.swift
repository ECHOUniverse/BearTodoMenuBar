import Foundation

extension Notification.Name {
    static let bearDatabaseAccessGranted = Notification.Name("bearDatabaseAccessGranted")
}

class BearBookmarkManager {
    static let shared = BearBookmarkManager()
    private let bookmarkKey = "bear_database_bookmark"

    var hasBookmark: Bool {
        UserDefaults.standard.data(forKey: bookmarkKey) != nil
    }

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
            return true
        } catch {
            print("Failed to save bookmark: \(error)")
            return false
        }
    }

    func resolveBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
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
                UserDefaults.standard.removeObject(forKey: bookmarkKey)
                return nil
            }
            return url
        } catch {
            print("Failed to resolve bookmark: \(error)")
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
            return nil
        }
    }

    @discardableResult
    func startAccessing() -> Bool {
        guard let url = resolveBookmark() else {
            return false
        }
        return url.startAccessingSecurityScopedResource()
    }

    func stopAccessing() {
        guard let url = resolveBookmark() else { return }
        url.stopAccessingSecurityScopedResource()
    }
}
