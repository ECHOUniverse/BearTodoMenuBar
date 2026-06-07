import AppKit
import EventKit
import ServiceManagement
import SwiftUI

// MARK: - Settings Tab

private enum SettingsTab: String, CaseIterable {
    case general
    case sync

    var title: String {
        switch self {
        case .general: return L10n.generalSettings
        case .sync: return L10n.syncIntegration
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .sync: return "arrow.triangle.2.circlepath"
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var l10n = L10n.shared
    @State private var showError = false
    @State private var errorMessage: String = ""
    @State private var isAuthorized: Bool = false
    @State private var reminderAccessStatus: EKAuthorizationStatus = .notDetermined
    @State private var animateContent = true
    @State private var selectedTab: SettingsTab = .general
    @Namespace private var tabNamespace
    @Namespace private var languageNamespace
    @Namespace private var monitorMethodNamespace

    // Draft state — buffered, committed only on Save
    @State private var draftReminderSync: Bool
    @State private var draftLaunchAtLogin: Bool
    @State private var draftCompletedSection: Bool
    @State private var draftSyncIntervalIndex: Double
    @State private var draftLanguage: Language
    @State private var draftMonitorMethod: BearMonitorMethod

    private let syncValues = [0, 1, 3, 5, 7]

    init() {
        let storedInterval = KeychainStorage.shared.syncInterval
        let validValues = [0, 1, 3, 5, 7]
        let idx = Double(validValues.firstIndex(of: storedInterval) ?? 0)

        _draftReminderSync = State(initialValue: KeychainStorage.shared.isReminderSyncEnabled)
        _draftLaunchAtLogin = State(initialValue: KeychainStorage.shared.isLaunchAtLoginEnabled)
        _draftCompletedSection = State(initialValue: KeychainStorage.shared.isCompletedSectionVisible)
        _draftSyncIntervalIndex = State(initialValue: idx)
        _draftLanguage = State(initialValue: L10n.shared.language)
        _draftMonitorMethod = State(initialValue: KeychainStorage.shared.bearMonitorMethod)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.settings)
                        .font(.title)
                        .fontWeight(.bold)
                    Text(L10n.settingsDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 16)
                .staggeredEntrance(0, animate: animateContent)
                .animation(nil, value: selectedTab)

                // Tab switcher
                tabSwitcher
                    .padding(.bottom, 16)
                    .staggeredEntrance(1, animate: animateContent)
                    .animation(nil, value: selectedTab)

                // Content area — both tabs always rendered to keep layout height stable
                ZStack {
                    VStack(alignment: .leading, spacing: 8) {
                        generalTabContent
                    }
                    .opacity(selectedTab == .general ? 1 : 0)
                    .offset(x: selectedTab == .general ? 0 : -30)

                    VStack(alignment: .leading, spacing: 8) {
                        syncTabContent
                    }
                    .opacity(selectedTab == .sync ? 1 : 0)
                    .offset(x: selectedTab == .sync ? 0 : 30)
                }
                .frame(maxWidth: .infinity)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)
                .staggeredEntrance(2, animate: animateContent)

                Spacer(minLength: 16)

                // Bottom bar: GitHub + Save/Cancel
                HStack {
                    Link(destination: URL(string: "https://github.com/ECHOUniverse/BearTodoMenuBar")!) {
                        Image(nsImage: Self.gitHubIcon)
                            .resizable()
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(L10n.cancel) {
                        closeWindow()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    Button(L10n.save) {
                        saveSettings()
                    }
                    .fontWeight(.semibold)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                .staggeredEntrance(3, animate: animateContent)
            }
            .padding(24)
        }
        .onAppear {
            isAuthorized = BearBookmarkManager.shared.hasBookmark
            reminderAccessStatus = EKEventStore.authorizationStatus(for: .reminder)
        }
    }

    // MARK: - Tab Switcher

    @ViewBuilder
    private var tabSwitcher: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(SettingsTab.allCases, id: \.self) { tab in
                        let label = HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13, weight: .medium))
                            Text(tab.title)
                                .font(.callout)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)

                        if selectedTab == tab {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    selectedTab = tab
                                }
                            } label: { label }
                            .buttonStyle(.plain)
                            .glassEffect(.regular.interactive(), in: Capsule())
                            .glassEffectID(tab.rawValue, in: tabNamespace)
                        } else {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    selectedTab = tab
                                }
                            } label: { label }
                            .buttonStyle(.plain)
                            .glassEffectID(tab.rawValue, in: tabNamespace)
                        }
                    }
                }
            }
            .padding(4)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
            )
            .frame(maxWidth: .infinity)
        } else {
            Picker("", selection: $selectedTab) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13, weight: .medium))
                        Text(tab.title)
                    }
                    .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Language Switcher

    @ViewBuilder
    private var languageSwitcher: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(Language.allCases, id: \.self) { lang in
                        let label = Text(lang.displayName)
                            .font(.callout)
                            .fontWeight(.medium)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)

                        if draftLanguage == lang {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    draftLanguage = lang
                                    l10n.language = lang
                                }
                            } label: { label }
                            .buttonStyle(.plain)
                            .glassEffect(.regular.interactive(), in: Capsule())
                            .glassEffectID(lang.rawValue, in: languageNamespace)
                        } else {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    draftLanguage = lang
                                    l10n.language = lang
                                }
                            } label: { label }
                            .buttonStyle(.plain)
                            .glassEffectID(lang.rawValue, in: languageNamespace)
                        }
                    }
                }
            }
            .padding(4)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
            )
            .frame(maxWidth: .infinity)
        } else {
            Picker("", selection: $draftLanguage) {
                ForEach(Language.allCases, id: \.self) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: draftLanguage) { lang in
                l10n.language = lang
            }
        }
    }

    // MARK: - Monitor Method Switcher

    @ViewBuilder
    private var monitorMethodSwitcher: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(BearMonitorMethod.allCases, id: \.self) { method in
                        let label = Text(method.displayName)
                            .font(.callout)
                            .fontWeight(.medium)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)

                        if draftMonitorMethod == method {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    draftMonitorMethod = method
                                }
                            } label: { label }
                            .buttonStyle(.plain)
                            .glassEffect(.regular.interactive(), in: Capsule())
                            .glassEffectID(method.rawValue, in: monitorMethodNamespace)
                        } else {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    draftMonitorMethod = method
                                }
                            } label: { label }
                            .buttonStyle(.plain)
                            .glassEffectID(method.rawValue, in: monitorMethodNamespace)
                        }
                    }
                }
            }
            .padding(4)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
            )
            .frame(maxWidth: .infinity)
        } else {
            Picker("", selection: $draftMonitorMethod) {
                ForEach(BearMonitorMethod.allCases, id: \.self) { method in
                    Text(method.displayName).tag(method)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var generalTabContent: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(L10n.language)
                        .font(.headline)
                    Spacer()
                }

                languageSwitcher
            }
        }

        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "power")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(L10n.launchAtLogin)
                        .font(.headline)
                    Spacer()
                }

                Toggle(isOn: $draftLaunchAtLogin) {
                    Text(L10n.launchAtLoginToggle)
                        .font(.callout)
                }
                .toggleStyle(.switch)

                Text(L10n.launchAtLoginDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(L10n.showCompletedSection)
                        .font(.headline)
                    Spacer()
                }

                Toggle(isOn: $draftCompletedSection) {
                    Text(L10n.showCompletedSectionDescription)
                        .font(.callout)
                }
                .toggleStyle(.switch)
            }
        }
    }

    @ViewBuilder
    private var syncTabContent: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "bell.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(L10n.systemReminders)
                        .font(.headline)
                    Spacer()
                    StatusPill(
                        icon: reminderAccessIcon,
                        text: reminderAccessTextShort,
                        color: reminderAccessColor
                    )
                    .animation(.default, value: reminderAccessStatus)
                }

                Toggle(isOn: $draftReminderSync) {
                    Text(L10n.enableSync)
                        .font(.callout)
                }
                .toggleStyle(.switch)

                if !reminderAccessDescription.isEmpty {
                    Text(reminderAccessDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }

        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(L10n.syncInterval)
                        .font(.headline)
                }

                Slider(value: $draftSyncIntervalIndex, in: 0...4, step: 1)

                Text(L10n.syncIntervalDescription(syncValues[Int(draftSyncIntervalIndex)]))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                    .animation(.default, value: draftSyncIntervalIndex)
            }
        }

        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(L10n.bearMonitorMethod)
                        .font(.headline)
                    Spacer()
                    if draftMonitorMethod == .fileWatcher {
                        StatusPill(
                            icon: isAuthorized ? "checkmark" : "exclamationmark",
                            text: isAuthorized ? L10n.authorized : L10n.notAuthorized,
                            color: isAuthorized ? .green : .orange
                        )
                        .animation(.default, value: isAuthorized)
                    }
                }

                monitorMethodSwitcher

                Text(draftMonitorMethod == .fileWatcher
                     ? L10n.bearMonitorFileWatcherDesc
                     : L10n.bearMonitorPollingDesc)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if draftMonitorMethod == .fileWatcher && !isAuthorized {
                    Button {
                        requestBookmark()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.open.fill")
                            Text(L10n.authorizeAccess)
                        }
                        .font(.callout)
                        .fontWeight(.medium)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }
        }
    }

    // MARK: - Save

    private func saveSettings() {
        // Reminders sync toggle
        if draftReminderSync != KeychainStorage.shared.isReminderSyncEnabled {
            KeychainStorage.shared.isReminderSyncEnabled = draftReminderSync
            if draftReminderSync {
                Task {
                    _ = await ReminderService.shared.requestAccess()
                }
            }
        }

        // Sync interval
        let interval = syncValues[Int(draftSyncIntervalIndex)]
        if interval != KeychainStorage.shared.syncInterval {
            KeychainStorage.shared.syncInterval = interval
        }

        // Launch at login
        if draftLaunchAtLogin != KeychainStorage.shared.isLaunchAtLoginEnabled {
            KeychainStorage.shared.isLaunchAtLoginEnabled = draftLaunchAtLogin
            if draftLaunchAtLogin {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }

        // Completed section visibility
        if draftCompletedSection != KeychainStorage.shared.isCompletedSectionVisible {
            KeychainStorage.shared.isCompletedSectionVisible = draftCompletedSection
        }

        // Monitor method
        if draftMonitorMethod != KeychainStorage.shared.bearMonitorMethod {
            KeychainStorage.shared.bearMonitorMethod = draftMonitorMethod
        }

        closeWindow()
    }

    // MARK: - Close Window

    private func closeWindow() {
        NSApp.keyWindow?.orderOut(nil)
    }

    // MARK: - GitHub Icon

    private static var gitHubIcon: NSImage = {
        guard let url = Bundle.module.url(forResource: "github-mark", withExtension: "png"),
            let image = NSImage(contentsOf: url)
        else {
            return NSImage()
        }
        image.isTemplate = true
        return image
    }()

    // MARK: - Reminder Access Helpers

    private var reminderAccessIcon: String {
        switch reminderAccessStatus {
        case .authorized: return "checkmark"
        case .denied, .restricted: return "xmark"
        case .notDetermined: return "exclamationmark"
        default:
            if #available(macOS 14.0, *), reminderAccessStatus == .fullAccess {
                return "checkmark"
            }
            return "exclamationmark"
        }
    }

    private var reminderAccessColor: Color {
        switch reminderAccessStatus {
        case .authorized: return .green
        case .denied, .restricted: return .red
        case .notDetermined: return .orange
        default:
            if #available(macOS 14.0, *), reminderAccessStatus == .fullAccess {
                return .green
            }
            return .orange
        }
    }

    private var reminderAccessTextShort: String {
        switch reminderAccessStatus {
        case .authorized: return L10n.reminderAccessAllowed
        case .denied: return L10n.reminderAccessDeniedText
        case .restricted: return L10n.reminderAccessRestricted
        case .notDetermined: return L10n.reminderAccessPending
        default:
            if #available(macOS 14.0, *), reminderAccessStatus == .fullAccess {
                return L10n.reminderAccessAllowed
            }
            return L10n.reminderAccessUnknown
        }
    }

    private var reminderAccessDescription: String {
        switch reminderAccessStatus {
        case .authorized:
            return L10n.reminderAccessGrantedDesc
        case .denied:
            return L10n.reminderAccessDeniedDesc
        case .restricted:
            return L10n.reminderAccessRestrictedDesc
        case .notDetermined:
            return L10n.reminderAccessPendingDesc
        default:
            if #available(macOS 14.0, *), reminderAccessStatus == .fullAccess {
                return L10n.reminderAccessGrantedDesc
            }
            return ""
        }
    }

    // MARK: - Bookmark Request

    private func requestBookmark() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.authorizePrompt
        panel.message = L10n.authorizeMessage

        if let dbURL = BearFileWatcher.findBearDatabasePath() {
            panel.directoryURL = dbURL.deletingLastPathComponent()
        } else {
            let groupContainersURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Group Containers")
            panel.directoryURL = groupContainersURL
        }

        let targetWindow = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first
        guard let window = targetWindow else {
            errorMessage = L10n.cannotOpenPanel
            showError = true
            return
        }

        panel.beginSheetModal(for: window) { result in
            if result == .OK, let url = panel.url {
                if BearBookmarkManager.shared.saveBookmark(for: url) {
                    isAuthorized = true
                    NotificationCenter.default.post(name: .bearDatabaseAccessGranted, object: nil)
                } else {
                    errorMessage = L10n.saveAuthFailed
                    showError = true
                }
            }
        }
    }
}
