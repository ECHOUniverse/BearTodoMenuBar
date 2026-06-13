import Foundation

@Observable @MainActor
final class L10n {
    static let shared = L10n()

    private init() {
        NotificationCenter.default.addObserver(forName: .appLanguageDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?._update() }
        }
    }

    private func _update() {}
    private var storage: KeychainStorage { KeychainStorage.shared }

    var language: Language {
        get { storage.language }
        set { storage.language = newValue }
    }

    var resolvedLanguage: Language { language.resolved }

    private func tr(_ key: StringKey) -> String {
        let table = resolvedLanguage == .simplifiedChinese ? zh : en
        return table[key] ?? en[key] ?? ""
    }

    private enum StringKey: Hashable { case set, setDesc, sysRem, enSync, auth, notAuth, authAcc, authPrompt, authMsg, lang, remAllow, remDeny, remRestr, remPend, remUnk, remAllowD, remDenyD, remRestrD, remPendD, refresh, refNow, lastUp, noDBAuth, noTodo, setMenu, quit, remSec, today, tomorrow, sch, overdue, unsched, pause, resume, comp, login, loginTog, loginDesc, syncInt, syncImm, syncVal, showComp, showCompD, allDone, save, cancel, general, syncIntg, bearMon, bearFW, bearPoll, bearFWDesc, bearPollDesc, about, appVer, chkUpd, chking, upToDate, updFail, openDL, newVer }

    private let zh: [StringKey: String] = [
        .set: "设置", .setDesc: "配置 Bear 待办同步选项", .sysRem: "系统提醒事项", .enSync: "启用同步",
        .auth: "已授权", .notAuth: "未授权", .authAcc: "授权访问", .authPrompt: "授权访问",
        .authMsg: "请选择 Bear 的 Application Data 目录", .lang: "语言 / Language",
        .remAllow: "已允许", .remDeny: "已拒绝", .remRestr: "受限制", .remPend: "待授权", .remUnk: "未知",
        .remAllowD: "提醒事项权限已获取。", .remDenyD: "权限已被拒绝，请前往系统设置开启。",
        .remRestrD: "权限受限制。", .remPendD: "开启后将请求提醒事项权限。",
        .refresh: "⏳ 刷新中...", .refNow: "立即刷新", .lastUp: "上次更新：%@",
        .noDBAuth: "⚠️ 未授权数据库访问", .noTodo: "暂无待办事项", .setMenu: "设置...", .quit: "退出",
        .remSec: "系统提醒事项", .today: "今天", .tomorrow: "明天", .sch: "已安排", .overdue: "已逾期",
        .unsched: "未安排", .pause: "暂停同步", .resume: "开始同步", .comp: "已完成",
        .login: "开机启动", .loginTog: "开机时自动启动", .loginDesc: "开启后应用将在登录时自动启动",
        .syncInt: "同步间隔", .syncImm: "立即同步", .syncVal: "延迟 %d 秒后同步",
        .showComp: "显示已完成事项", .showCompD: "在菜单栏中显示已完成的待办事项",
        .allDone: "已全部完成 ✓", .save: "保存", .cancel: "取消", .general: "一般设置", .syncIntg: "同步与集成",
        .bearMon: "Bear 文件监控方式", .bearFW: "文件监控", .bearPoll: "Bear 轮询",
        .bearFWDesc: "通过文件系统监控 Bear 数据库变更。", .bearPollDesc: "定时通过 bearcli 检查变更。",
        .about: "关于与更新", .appVer: "版本", .chkUpd: "检查更新", .chking: "正在检查...",
        .upToDate: "已是最新版本", .updFail: "检查更新失败", .openDL: "打开下载页面",
    ]

    private let en: [StringKey: String] = [
        .set: "Settings", .setDesc: "Configure Bear Todo sync options", .sysRem: "System Reminders",
        .enSync: "Enable Sync", .auth: "Authorized", .notAuth: "Not Authorized", .authAcc: "Authorize Access",
        .authPrompt: "Authorize Access", .authMsg: "Please select Bear's Application Data directory",
        .lang: "Language", .remAllow: "Allowed", .remDeny: "Denied", .remRestr: "Restricted",
        .remPend: "Pending", .remUnk: "Unknown", .remAllowD: "Reminder access granted.",
        .remDenyD: "Permission denied. Enable in System Settings.", .remRestrD: "Access restricted.",
        .remPendD: "Permission will be requested when enabled.", .refresh: "⏳ Refreshing...",
        .refNow: "Refresh Now", .lastUp: "Last updated: %@", .noDBAuth: "⚠️ Database access not authorized",
        .noTodo: "No todo items", .setMenu: "Settings...", .quit: "Quit", .remSec: "Reminders",
        .today: "Today", .tomorrow: "Tomorrow", .sch: "Scheduled", .overdue: "Overdue",
        .unsched: "Unscheduled", .pause: "Pause Sync", .resume: "Resume Sync", .comp: "Completed",
        .login: "Launch at Login", .loginTog: "Launch at Login",
        .loginDesc: "App will automatically launch when you log in",
        .syncInt: "Sync Interval", .syncImm: "Immediate", .syncVal: "Sync after %d s",
        .showComp: "Show Completed Items", .showCompD: "Display completed todos in the menu bar",
        .allDone: "All completed ✓", .save: "Save", .cancel: "Cancel", .general: "General",
        .syncIntg: "Sync & Integration", .bearMon: "Bear Monitor Method", .bearFW: "File Watcher",
        .bearPoll: "Bear Polling", .bearFWDesc: "Monitor Bear database changes via file system.",
        .bearPollDesc: "Periodically check via bearcli.", .about: "About & Updates",
        .appVer: "Version", .chkUpd: "Check for Updates", .chking: "Checking...",
        .upToDate: "Up to Date", .updFail: "Update Check Failed", .openDL: "Open Download Page",
    ]

    var settings: String { tr(.set) }; var settingsDescription: String { tr(.setDesc) }
    var systemReminders: String { tr(.sysRem) }; var enableSync: String { tr(.enSync) }
    var authorized: String { tr(.auth) }; var notAuthorized: String { tr(.notAuth) }
    var authorizeAccess: String { tr(.authAcc) }; var authorizePrompt: String { tr(.authPrompt) }
    var authorizeMessage: String { tr(.authMsg) }; var languageTitle: String { tr(.lang) }
    var reminderAccessAllowed: String { tr(.remAllow) }; var reminderAccessDeniedText: String { tr(.remDeny) }
    var reminderAccessRestricted: String { tr(.remRestr) }; var reminderAccessPending: String { tr(.remPend) }
    var reminderAccessUnknown: String { tr(.remUnk) }; var reminderAccessGrantedDesc: String { tr(.remAllowD) }
    var reminderAccessDeniedDesc: String { tr(.remDenyD) }; var reminderAccessRestrictedDesc: String { tr(.remRestrD) }
    var reminderAccessPendingDesc: String { tr(.remPendD) }; var refreshing: String { tr(.refresh) }
    var refreshNow: String { tr(.refNow) }; var noDatabaseAuth: String { tr(.noDBAuth) }
    var noTodos: String { tr(.noTodo) }; var settingsMenu: String { tr(.setMenu) }; var quit: String { tr(.quit) }
    var remindersSection: String { tr(.remSec) }; var todaySection: String { tr(.today) }
    var tomorrowSection: String { tr(.tomorrow) }; var scheduledSection: String { tr(.sch) }
    var overdueSection: String { tr(.overdue) }; var unscheduledSection: String { tr(.unsched) }
    var pauseSync: String { tr(.pause) }; var resumeSync: String { tr(.resume) }
    var completedSection: String { tr(.comp) }; var launchAtLogin: String { tr(.login) }
    var launchAtLoginToggle: String { tr(.loginTog) }; var launchAtLoginDescription: String { tr(.loginDesc) }
    var syncInterval: String { tr(.syncInt) }; var syncIntervalImmediate: String { tr(.syncImm) }
    var showCompletedSection: String { tr(.showComp) }; var showCompletedSectionDescription: String { tr(.showCompD) }
    var allBearTodosCompleted: String { tr(.allDone) }; var save: String { tr(.save) }; var cancel: String { tr(.cancel) }
    var generalSettings: String { tr(.general) }; var syncIntegration: String { tr(.syncIntg) }
    var bearMonitorMethod: String { tr(.bearMon) }; var bearMonitorFileWatcher: String { tr(.bearFW) }
    var bearMonitorPolling: String { tr(.bearPoll) }; var bearMonitorFileWatcherDesc: String { tr(.bearFWDesc) }
    var bearMonitorPollingDesc: String { tr(.bearPollDesc) }; var about: String { tr(.about) }
    var appVersion: String { tr(.appVer) }; var checkForUpdates: String { tr(.chkUpd) }
    var checking: String { tr(.chking) }; var upToDate: String { tr(.upToDate) }
    var updateFailed: String { tr(.updFail) }; var openDownloadPage: String { tr(.openDL) }
    func lastUpdate(_ t: String) -> String { String(format: tr(.lastUp), t) }
    func syncIntervalDescription(_ s: Int) -> String { s == 0 ? tr(.syncImm) : String(format: tr(.syncVal), s) }
    func newVersionAvailable(_ v: String) -> String { String(format: tr(.newVer), v) }
}
