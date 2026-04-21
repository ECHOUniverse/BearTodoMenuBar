import SwiftUI

extension Notification.Name {
    static let appLanguageDidChange = Notification.Name("appLanguageDidChange")
}

enum Language: String, CaseIterable, Codable {
    case auto
    case simplifiedChinese
    case english

    var displayName: String {
        switch self {
        case .auto: return "自动（跟随系统）"
        case .simplifiedChinese: return "简体中文"
        case .english: return "English"
        }
    }
}

final class L10n: ObservableObject {
    static let shared = L10n()

    @AppStorage("app_language") var language: Language = .auto

    var resolvedLanguage: Language {
        switch language {
        case .auto:
            return Locale.preferredLanguages.first?.hasPrefix("zh") == true ? .simplifiedChinese : .english
        case .simplifiedChinese, .english:
            return language
        }
    }

    private var cancellable: Any?

    init() {
        cancellable = UserDefaults.standard.observe(\.app_language_raw, options: [.new]) { [weak self] _, _ in
            self?.objectWillChange.send()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .appLanguageDidChange, object: nil)
            }
        }
    }

    private enum StringKey {
        case settings
        case settingsDescription
        case bearApiToken
        case apiTokenHint
        case apiTokenPlaceholder
        case systemReminders
        case enableSync
        case databaseAccess
        case authorized
        case notAuthorized
        case accessGranted
        case accessNotGranted
        case reauthorize
        case authorizeAccess
        case cancel
        case save
        case saveSuccess
        case saveFailed
        case ok
        case tokenEmpty
        case reminderAccessDenied
        case authorizePrompt
        case authorizeMessage
        case cannotOpenPanel
        case saveAuthFailed
        case language
        case languageAuto
        case languageChinese
        case languageEnglish
        case reminderAccessAllowed
        case reminderAccessDeniedText
        case reminderAccessRestricted
        case reminderAccessPending
        case reminderAccessUnknown
        case reminderAccessGrantedDesc
        case reminderAccessDeniedDesc
        case reminderAccessRestrictedDesc
        case reminderAccessPendingDesc
        case refreshing
        case lastUpdate
        case refreshNow
        case configureTokenFirst
        case noDatabaseAuth
        case noTodos
        case completedSection
        case moreItems
        case openInBear
        case settingsMenu
        case quit
    }

    private static let zhStrings: [StringKey: String] = [
            .settings: "设置",
            .settingsDescription: "配置 Bear 待办同步选项",
            .bearApiToken: "Bear API Token",
            .apiTokenHint: "在 Bear 应用中选择 Help → API Token 获取你的个人 Token。",
            .apiTokenPlaceholder: "输入 API Token",
            .systemReminders: "系统提醒事项",
            .enableSync: "启用同步",
            .databaseAccess: "数据库访问授权",
            .authorized: "已授权",
            .notAuthorized: "未授权",
            .accessGranted: "已授权访问 Bear 数据库，自动刷新可用。",
            .accessNotGranted: "未授权访问 Bear 数据库，自动刷新功能不可用。",
            .reauthorize: "重新授权",
            .authorizeAccess: "授权访问",
            .cancel: "取消",
            .save: "保存",
            .saveSuccess: "保存成功",
            .saveFailed: "保存失败",
            .ok: "确定",
            .tokenEmpty: "Token 不能为空",
            .reminderAccessDenied: "无法访问提醒事项，请检查系统权限设置",
            .authorizePrompt: "授权访问",
            .authorizeMessage: "请选择 Bear 的 Application Data 目录",
            .cannotOpenPanel: "无法打开文件选择器",
            .saveAuthFailed: "保存授权失败",
            .language: "语言 / Language",
            .languageAuto: "自动（跟随系统）",
            .languageChinese: "简体中文",
            .languageEnglish: "English",
            .reminderAccessAllowed: "已允许",
            .reminderAccessDeniedText: "已拒绝",
            .reminderAccessRestricted: "受限制",
            .reminderAccessPending: "待授权",
            .reminderAccessUnknown: "未知",
            .reminderAccessGrantedDesc: "提醒事项权限已获取，待办将自动同步到系统提醒事项。",
            .reminderAccessDeniedDesc: "权限已被拒绝，请前往系统设置 → 隐私与安全性 → 提醒事项中开启。",
            .reminderAccessRestrictedDesc: "权限受限制，无法访问提醒事项。",
            .reminderAccessPendingDesc: "开启开关后将请求提醒事项权限。",
            .refreshing: "⏳ 刷新中...",
            .lastUpdate: "上次更新：%@",
            .refreshNow: "立即刷新",
            .configureTokenFirst: "请先配置 API Token",
            .noDatabaseAuth: "⚠️ 未授权数据库访问，自动刷新不可用",
            .noTodos: "暂无待办事项",
            .completedSection: "已完成（来自提醒事项）",
            .moreItems: "更多...（还有 %d 条）",
            .openInBear: "在 Bear 中打开",
            .settingsMenu: "设置...",
            .quit: "退出"
        ]

        private static let enStrings: [StringKey: String] = [
            .settings: "Settings",
            .settingsDescription: "Configure Bear Todo sync options",
            .bearApiToken: "Bear API Token",
            .apiTokenHint: "Get your personal token from Bear app: Help → API Token.",
            .apiTokenPlaceholder: "Enter API Token",
            .systemReminders: "System Reminders",
            .enableSync: "Enable Sync",
            .databaseAccess: "Database Access Authorization",
            .authorized: "Authorized",
            .notAuthorized: "Not Authorized",
            .accessGranted: "Database access authorized, auto-refresh available.",
            .accessNotGranted: "Database access not authorized, auto-refresh unavailable.",
            .reauthorize: "Re-authorize",
            .authorizeAccess: "Authorize Access",
            .cancel: "Cancel",
            .save: "Save",
            .saveSuccess: "Saved",
            .saveFailed: "Save Failed",
            .ok: "OK",
            .tokenEmpty: "Token cannot be empty",
            .reminderAccessDenied: "Cannot access Reminders, please check system permission settings",
            .authorizePrompt: "Authorize Access",
            .authorizeMessage: "Please select Bear's Application Data directory",
            .cannotOpenPanel: "Cannot open file chooser",
            .saveAuthFailed: "Failed to save authorization",
            .language: "Language",
            .languageAuto: "Auto (Follow System)",
            .languageChinese: "简体中文",
            .languageEnglish: "English",
            .reminderAccessAllowed: "Allowed",
            .reminderAccessDeniedText: "Denied",
            .reminderAccessRestricted: "Restricted",
            .reminderAccessPending: "Pending",
            .reminderAccessUnknown: "Unknown",
            .reminderAccessGrantedDesc: "Reminder access granted, todos will sync to Reminders.",
            .reminderAccessDeniedDesc: "Permission denied. Go to System Settings → Privacy & Security → Reminders to enable.",
            .reminderAccessRestrictedDesc: "Access restricted, cannot access Reminders.",
            .reminderAccessPendingDesc: "Permission will be requested when enabled.",
            .refreshing: "⏳ Refreshing...",
            .lastUpdate: "Last updated: %@",
            .refreshNow: "Refresh Now",
            .configureTokenFirst: "Please configure API Token first",
            .noDatabaseAuth: "⚠️ Database access not authorized, auto-refresh unavailable",
            .noTodos: "No todo items",
            .completedSection: "Completed (from Reminders)",
            .moreItems: "More... (%d remaining)",
            .openInBear: "Open in Bear",
            .settingsMenu: "Settings...",
            .quit: "Quit"
        ]

        private static func tr(_ key: StringKey) -> String {
            let table: [StringKey: String]
            switch shared.resolvedLanguage {
            case .simplifiedChinese: table = zhStrings
            case .english: table = enStrings
            case .auto: table = enStrings
            }
            return table[key] ?? enStrings[key] ?? ""
        }

    static var settings: String { tr(.settings) }
    static var settingsDescription: String { tr(.settingsDescription) }
    static var bearApiToken: String { tr(.bearApiToken) }
    static var apiTokenHint: String { tr(.apiTokenHint) }
    static var apiTokenPlaceholder: String { tr(.apiTokenPlaceholder) }
    static var systemReminders: String { tr(.systemReminders) }
    static var enableSync: String { tr(.enableSync) }
    static var databaseAccess: String { tr(.databaseAccess) }
    static var authorized: String { tr(.authorized) }
    static var notAuthorized: String { tr(.notAuthorized) }
    static var accessGranted: String { tr(.accessGranted) }
    static var accessNotGranted: String { tr(.accessNotGranted) }
    static var reauthorize: String { tr(.reauthorize) }
    static var authorizeAccess: String { tr(.authorizeAccess) }
    static var cancel: String { tr(.cancel) }
    static var save: String { tr(.save) }
    static var saveSuccess: String { tr(.saveSuccess) }
    static var saveFailed: String { tr(.saveFailed) }
    static var ok: String { tr(.ok) }
    static var tokenEmpty: String { tr(.tokenEmpty) }
    static var reminderAccessDenied: String { tr(.reminderAccessDenied) }
    static var authorizePrompt: String { tr(.authorizePrompt) }
    static var authorizeMessage: String { tr(.authorizeMessage) }
    static var cannotOpenPanel: String { tr(.cannotOpenPanel) }
    static var saveAuthFailed: String { tr(.saveAuthFailed) }
    static var language: String { tr(.language) }
    static var languageAuto: String { tr(.languageAuto) }
    static var languageChinese: String { tr(.languageChinese) }
    static var languageEnglish: String { tr(.languageEnglish) }
    static var reminderAccessAllowed: String { tr(.reminderAccessAllowed) }
    static var reminderAccessDeniedText: String { tr(.reminderAccessDeniedText) }
    static var reminderAccessRestricted: String { tr(.reminderAccessRestricted) }
    static var reminderAccessPending: String { tr(.reminderAccessPending) }
    static var reminderAccessUnknown: String { tr(.reminderAccessUnknown) }
    static var reminderAccessGrantedDesc: String { tr(.reminderAccessGrantedDesc) }
    static var reminderAccessDeniedDesc: String { tr(.reminderAccessDeniedDesc) }
    static var reminderAccessRestrictedDesc: String { tr(.reminderAccessRestrictedDesc) }
    static var reminderAccessPendingDesc: String { tr(.reminderAccessPendingDesc) }
    static var refreshing: String { tr(.refreshing) }
    static var refreshNow: String { tr(.refreshNow) }
    static var configureTokenFirst: String { tr(.configureTokenFirst) }
    static var noDatabaseAuth: String { tr(.noDatabaseAuth) }
    static var noTodos: String { tr(.noTodos) }
    static var completedSection: String { tr(.completedSection) }
    static var openInBear: String { tr(.openInBear) }
    static var settingsMenu: String { tr(.settingsMenu) }
    static var quit: String { tr(.quit) }

    static func lastUpdate(_ timeString: String) -> String {
        String(format: tr(.lastUpdate), timeString)
    }

    static func moreItems(_ count: Int) -> String {
        String(format: tr(.moreItems), count)
    }
}

private extension UserDefaults {
    @objc var app_language_raw: String {
        return string(forKey: "app_language") ?? ""
    }
}