import Foundation
import Security

extension Notification.Name {
    static let syncIntervalDidChange = Notification.Name("syncIntervalDidChange")
    static let bearMonitorMethodDidChange = Notification.Name("bearMonitorMethodDidChange")
    static let appLanguageDidChange = Notification.Name("appLanguageDidChange")
}

@Observable @MainActor
final class KeychainStorage: Sendable {
    static let shared = KeychainStorage()
    private let d = UserDefaults.standard

    var isReminderSyncEnabled: Bool {
        get { d.object(forKey: "bear_reminder_sync_enabled") != nil ? d.bool(forKey: "bear_reminder_sync_enabled") : false }
        set { d.set(newValue, forKey: "bear_reminder_sync_enabled"); writeKC("bear_reminder_sync_enabled", newValue ? "true" : "false") }
    }
    var isLaunchAtLoginEnabled: Bool {
        get { d.bool(forKey: "bear_launch_at_login_enabled") }
        set { d.set(newValue, forKey: "bear_launch_at_login_enabled") }
    }
    var isCompletedSectionVisible: Bool {
        get { d.object(forKey: "bear_show_completed_section") == nil ? true : d.bool(forKey: "bear_show_completed_section") }
        set { d.set(newValue, forKey: "bear_show_completed_section") }
    }
    var syncInterval: Int {
        get { d.integer(forKey: "bear_sync_interval") }
        set { d.set(newValue, forKey: "bear_sync_interval"); NotificationCenter.default.post(name: .syncIntervalDidChange, object: nil) }
    }
    var bearMonitorMethod: BearMonitorMethod {
        get { BearMonitorMethod(rawValue: d.string(forKey: "bear_monitor_method") ?? "") ?? .fileWatcher }
        set { d.set(newValue.rawValue, forKey: "bear_monitor_method"); NotificationCenter.default.post(name: .bearMonitorMethodDidChange, object: nil) }
    }
    var language: Language {
        get { Language(rawValue: d.string(forKey: "app_language") ?? "") ?? .auto }
        set { d.set(newValue.rawValue, forKey: "app_language"); NotificationCenter.default.post(name: .appLanguageDidChange, object: nil) }
    }
    private func writeKC(_ key: String, _ value: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.beartodo", kSecAttrAccount as String: key]
        SecItemDelete(q as CFDictionary)
        guard let d = value.data(using: .utf8) else { return }
        var aq = q; aq[kSecValueData as String] = d; aq[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(aq as CFDictionary, nil)
    }
}
