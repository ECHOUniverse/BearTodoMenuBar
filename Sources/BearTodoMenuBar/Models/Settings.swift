import Foundation

enum Language: String, CaseIterable, Codable, Sendable {
    case auto, simplifiedChinese, english
    var displayName: String {
        switch self {
        case .auto: "自动（跟随系统）"
        case .simplifiedChinese: "简体中文"
        case .english: "English"
        }
    }
    var resolved: Language {
        switch self {
        case .auto: Locale.preferredLanguages.first?.hasPrefix("zh") == true ? .simplifiedChinese : .english
        case .simplifiedChinese, .english: self
        }
    }
}

enum BearMonitorMethod: String, CaseIterable, Codable, Sendable {
    case fileWatcher, polling
    var displayName: String {
        switch self {
        case .fileWatcher: "文件监控"
        case .polling: "Bear 轮询"
        }
    }
}

enum SettingsTab: String, CaseIterable, Sendable {
    case general, sync, about
    var icon: String {
        switch self {
        case .general: "gearshape"
        case .sync: "arrow.triangle.2.circlepath"
        case .about: "info.circle.fill"
        }
    }
}
