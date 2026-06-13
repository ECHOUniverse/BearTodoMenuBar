import AppKit
import EventKit
import ServiceManagement
import SwiftUI

private enum UpdateCheckState: Equatable { case idle, checking, upToDate, updateAvailable(String), error(String) }

struct SettingsView: View {
    // Tab state
    @Namespace private var tabNS; @Namespace private var langNS; @Namespace private var monNS
    @State private var selectedTab = SettingsTab.general
    @State private var animateContent = true
    // Draft state
    @State private var draftReminderSync: Bool; @State private var draftLaunchAtLogin: Bool
    @State private var draftCompletedSection: Bool; @State private var draftSyncIntervalIndex: Double
    @State private var draftLanguage: Language; @State private var draftMonitorMethod: BearMonitorMethod
    // Auth state
    @State private var isAuthorized = false; @State private var reminderAccessStatus: EKAuthorizationStatus = .notDetermined
    // Update check
    @State private var updateCheckState: UpdateCheckState = .idle
    @State private var currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    @State private var appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "BearTodoMenuBar"
    private let syncValues = [0, 1, 3, 5, 7]
    private var storage: KeychainStorage { KeychainStorage.shared }; private var l10n: L10n { L10n.shared }

    init() {
        let s = KeychainStorage.shared; let idx = Double([0, 1, 3, 5, 7].firstIndex(of: s.syncInterval) ?? 0)
        self.draftReminderSync = s.isReminderSyncEnabled; self.draftLaunchAtLogin = s.isLaunchAtLoginEnabled
        self.draftCompletedSection = s.isCompletedSectionVisible; self.draftSyncIntervalIndex = idx
        self.draftLanguage = L10n.shared.language; self.draftMonitorMethod = s.bearMonitorMethod
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.settings).font(.title).fontWeight(.bold)
                    Text(l10n.settingsDescription).font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 16).staggeredEntrance(0, animate: animateContent).animation(nil, value: selectedTab)

                tabSwitcher.padding(.bottom, 16).staggeredEntrance(1, animate: animateContent).animation(nil, value: selectedTab)

                ZStack {
                    generalTabContent.opacity(selectedTab == .general ? 1 : 0).offset(x: selectedTab == .general ? 0 : -30)
                    syncTabContent.opacity(selectedTab == .sync ? 1 : 0).offset(x: selectedTab == .sync ? 0 : 30)
                    aboutTabContent.opacity(selectedTab == .about ? 1 : 0).offset(x: selectedTab == .about ? 0 : 30)
                }.frame(maxWidth: .infinity).animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab).staggeredEntrance(2, animate: animateContent)

                Spacer(minLength: 16)
                HStack {
                    if let url = URL(string: "https://github.com/ECHOUniverse/BearTodoMenuBar") {
                        Link(destination: url) { Image(systemName: "link.circle.fill").font(.system(size: 18)).foregroundStyle(.secondary) }.buttonStyle(.plain)
                    }
                    Spacer()
                    Button(l10n.cancel) { closeWindow() }.buttonStyle(.bordered).controlSize(.regular)
                    if selectedTab != .about { Button(l10n.save) { save() }.fontWeight(.semibold).buttonStyle(.borderedProminent).controlSize(.regular) }
                }.staggeredEntrance(3, animate: animateContent)
            }.padding(24)
        }
        .onAppear {
            isAuthorized = UserDefaults.standard.data(forKey: "bear_database_bookmark") != nil
            reminderAccessStatus = EKEventStore.authorizationStatus(for: .reminder)
        }
    }

    private var tabSwitcher: some View {
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    let label = HStack(spacing: 6) {
                        Image(systemName: tab.icon).font(.system(size: 13, weight: .medium))
                        Text(tab.rawValue == "general" ? l10n.generalSettings : (tab.rawValue == "sync" ? l10n.syncIntegration : l10n.about)).font(.callout).fontWeight(.medium)
                    }.padding(.horizontal, 20).padding(.vertical, 8)
                    Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { selectedTab = tab } } label: { label }
                        .buttonStyle(.plain)
                        .if(selectedTab == tab) { $0.glassEffect(.regular.interactive(), in: Capsule()) }
                        .glassEffectID(tab.rawValue, in: tabNS)
                }
            }
        }
        .padding(4).background(Capsule(style: .continuous).fill(.ultraThinMaterial).overlay(Capsule(style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 0.5)))
        .frame(maxWidth: .infinity)
    }

    private var generalTabContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            GlassCard { VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) { Image(systemName: "globe").font(.title3).foregroundStyle(.secondary); Text(l10n.languageTitle).font(.headline); Spacer() }
                GlassEffectTabSwitcher(tabs: Language.self, selection: $draftLanguage, labelFor: { Text($0.displayName) }, iconFor: nil, namespace: langNS) { lang in draftLanguage = lang; l10n.language = lang }
            }}
            GlassCard { VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) { Image(systemName: "power").font(.title3).foregroundStyle(.secondary); Text(l10n.launchAtLogin).font(.headline); Spacer() }
                Toggle(isOn: $draftLaunchAtLogin) { Text(l10n.launchAtLoginToggle).font(.callout) }.toggleStyle(.switch)
                Text(l10n.launchAtLoginDescription).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }}
            GlassCard { VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) { Image(systemName: "checkmark.circle").font(.title3).foregroundStyle(.secondary); Text(l10n.showCompletedSection).font(.headline); Spacer() }
                Toggle(isOn: $draftCompletedSection) { Text(l10n.showCompletedSectionDescription).font(.callout) }.toggleStyle(.switch)
            }}
        }
    }

    private var syncTabContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            GlassCard { VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) { Image(systemName: "bell.fill").font(.title3).foregroundStyle(.secondary); Text(l10n.systemReminders).font(.headline); Spacer()
                    StatusPill(icon: remAccessIcon, text: remAccessText, color: remAccessColor).animation(.default, value: reminderAccessStatus) }
                Toggle(isOn: $draftReminderSync) { Text(l10n.enableSync).font(.callout) }.toggleStyle(.switch)
                if !remAccessDesc.isEmpty { Text(remAccessDesc).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            }}
            GlassCard { VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) { Image(systemName: "clock.arrow.circlepath").font(.title3).foregroundStyle(.secondary); Text(l10n.syncInterval).font(.headline) }
                Slider(value: $draftSyncIntervalIndex, in: 0...4, step: 1)
                Text(l10n.syncIntervalDescription(syncValues[Int(draftSyncIntervalIndex)])).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).contentTransition(.opacity).animation(.default, value: draftSyncIntervalIndex)
            }}
            GlassCard { VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) { Image(systemName: "antenna.radiowaves.left.and.right").font(.title3).foregroundStyle(.secondary); Text(l10n.bearMonitorMethod).font(.headline); Spacer()
                    if draftMonitorMethod == .fileWatcher { StatusPill(icon: isAuthorized ? "checkmark" : "exclamationmark", text: isAuthorized ? l10n.authorized : l10n.notAuthorized, color: isAuthorized ? .green : .orange).animation(.default, value: isAuthorized) } }
                GlassEffectTabSwitcher(tabs: BearMonitorMethod.self, selection: $draftMonitorMethod, labelFor: { Text($0.displayName) }, iconFor: nil, namespace: monNS, onChange: nil)
                Text(draftMonitorMethod == .fileWatcher ? l10n.bearMonitorFileWatcherDesc : l10n.bearMonitorPollingDesc).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if draftMonitorMethod == .fileWatcher, !isAuthorized { Button { requestBookmark() } label: {
                    HStack(spacing: 6) { Image(systemName: "lock.open.fill"); Text(l10n.authorizeAccess) }.font(.callout).fontWeight(.medium) }.buttonStyle(.bordered).controlSize(.regular) }
            }}
        }
    }

    private func save() {
        if draftReminderSync != storage.isReminderSyncEnabled { storage.isReminderSyncEnabled = draftReminderSync; if draftReminderSync { Task { _ = await ReminderService.shared.requestAccess() } } }
        let interval = syncValues[Int(draftSyncIntervalIndex)]; if interval != storage.syncInterval { storage.syncInterval = interval }
        if draftLaunchAtLogin != storage.isLaunchAtLoginEnabled { storage.isLaunchAtLoginEnabled = draftLaunchAtLogin; if draftLaunchAtLogin { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() } }
        if draftCompletedSection != storage.isCompletedSectionVisible { storage.isCompletedSectionVisible = draftCompletedSection }
        if draftMonitorMethod != storage.bearMonitorMethod { storage.bearMonitorMethod = draftMonitorMethod }
        closeWindow()
    }

    private func closeWindow() { NSApp.keyWindow?.orderOut(nil) }

    private func requestBookmark() {
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false; panel.prompt = l10n.authorizePrompt; panel.message = l10n.authorizeMessage
        if let dbURL = MonitorService.findBearDatabasePath() { panel.directoryURL = dbURL.deletingLastPathComponent() }
        else { panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Group Containers") }
        guard let win = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first else { return }
        panel.beginSheetModal(for: win) { result in
            if result == .OK, let url = panel.url {
                if saveBookmark(url) { isAuthorized = true }
            }
        }
    }

    private func saveBookmark(_ url: URL) -> Bool {
        guard url.startAccessingSecurityScopedResource() else { return false }
        defer { url.stopAccessingSecurityScopedResource() }
        do { let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil); UserDefaults.standard.set(data, forKey: "bear_database_bookmark"); return true }
        catch { print("Bookmark save failed: \(error)"); return false }
    }

    private func checkForUpdates() {
        updateCheckState = .checking
        guard let url = URL(string: "https://api.github.com/repos/ECHOUniverse/BearTodoMenuBar/releases/latest") else { updateCheckState = .error("Invalid URL"); return }
        URLSession.shared.dataTask(with: URLRequest(url: url, timeoutInterval: 10)) { data, _, error in
            DispatchQueue.main.async {
                if error != nil { updateCheckState = .error(error?.localizedDescription ?? "Unknown"); return }
                guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let tagName = json["tag_name"] as? String else { updateCheckState = .error("Parse failed"); return }
                let remote = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
                let parts1 = remote.split(separator: ".").compactMap { Int($0) }; let parts2 = currentVersion.split(separator: ".").compactMap { Int($0) }
                let maxLen = max(parts1.count, parts2.count); var newer = false
                for i in 0..<maxLen { let a = i < parts1.count ? parts1[i] : 0; let b = i < parts2.count ? parts2[i] : 0; if a > b { newer = true; break }; if a < b { break } }
                updateCheckState = newer ? .updateAvailable(remote) : .upToDate
            }
        }.resume()
    }

    private var remAccessIcon: String {
        switch reminderAccessStatus {
        case .notDetermined: "exclamationmark"
        case .denied, .restricted: "xmark"
        case .fullAccess: "checkmark"
        default: "checkmark"
        }
    }
    private var remAccessColor: Color {
        switch reminderAccessStatus {
        case .notDetermined: .orange; case .denied, .restricted: .red; case .fullAccess: .green; default: .green
        }
    }
    private var remAccessText: String {
        switch reminderAccessStatus {
        case .notDetermined: l10n.reminderAccessPending; case .denied: l10n.reminderAccessDeniedText
        case .restricted: l10n.reminderAccessRestricted; case .fullAccess: l10n.reminderAccessAllowed; default: l10n.reminderAccessAllowed
        }
    }
    private var remAccessDesc: String {
        switch reminderAccessStatus {
        case .notDetermined: l10n.reminderAccessPendingDesc; case .denied: l10n.reminderAccessDeniedDesc
        case .restricted: l10n.reminderAccessRestrictedDesc; case .fullAccess: ""; default: ""
        }
    }

    private var aboutTabContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            GlassCard { VStack(spacing: 16) {
                if let img = NSApp.applicationIconImage { Image(nsImage: img).resizable().frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)) }
                Text(appName).font(.title2).fontWeight(.bold)
                VStack(spacing: 4) { HStack(spacing: 6) { Text(l10n.appVersion).foregroundStyle(.secondary); Text(currentVersion).fontWeight(.medium) }.font(.callout); Text("© 2025 ECHOUniverse").font(.caption).foregroundStyle(.secondary) }
            }.frame(maxWidth: .infinity).padding(.vertical, 8) }
            GlassCard { VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) { Image(systemName: "arrow.down.circle").font(.title3).foregroundStyle(.secondary); Text(l10n.checkForUpdates).font(.headline); Spacer() }
                switch updateCheckState {
                case .idle: Button { checkForUpdates() } label: { HStack(spacing: 6) { Image(systemName: "arrow.clockwise"); Text(l10n.checkForUpdates) }.font(.callout).fontWeight(.medium).frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).controlSize(.regular)
                case .checking: HStack(spacing: 8) { ProgressView().scaleEffect(0.8); Text(l10n.checking).font(.callout).foregroundStyle(.secondary) }
                case .upToDate: HStack(spacing: 6) { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green); Text(l10n.upToDate).font(.callout).fontWeight(.medium).foregroundStyle(.green) }.padding(.vertical, 4)
                case .updateAvailable(let v): VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) { Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange); Text(l10n.newVersionAvailable(v)).font(.callout).fontWeight(.medium).foregroundStyle(.orange) }
                    if let url = URL(string: "https://github.com/ECHOUniverse/BearTodoMenuBar/releases/latest") { Link(destination: url) { HStack(spacing: 6) { Image(systemName: "arrow.down.to.line"); Text(l10n.openDownloadPage) }.font(.callout).fontWeight(.medium).frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).controlSize(.regular) }
                }
                case .error(let m): HStack(spacing: 6) { Image(systemName: "xmark.circle.fill").foregroundStyle(.red); Text(m).font(.callout).foregroundStyle(.secondary) }
                }
            }}
        }
    }
}

