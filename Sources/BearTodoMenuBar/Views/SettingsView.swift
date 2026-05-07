import SwiftUI
import AppKit
import EventKit
import ServiceManagement

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var l10n = L10n.shared
    @AppStorage("app_language") var language: Language = .auto
    @State private var showError = false
    @State private var errorMessage: String = ""
    @State private var isAuthorized: Bool = false
    @State private var isReminderSyncEnabled: Bool = false
    @State private var isLaunchAtLoginEnabled: Bool = false
    @State private var reminderAccessStatus: EKAuthorizationStatus = .notDetermined
    @State private var isCompletedSectionVisible: Bool = false
    @State private var syncIntervalIndex: Double = 0
    @State private var animateContent = true

    private let syncValues = [0, 1, 3, 5, 7]

    init() {
        // Initialize persisted toggle states before the view renders,
        // so onChange handlers don't fire on initial appearance.
        _isReminderSyncEnabled = State(initialValue: KeychainStorage.shared.isReminderSyncEnabled)
        _isLaunchAtLoginEnabled = State(initialValue: KeychainStorage.shared.isLaunchAtLoginEnabled)
        _isCompletedSectionVisible = State(initialValue: KeychainStorage.shared.isCompletedSectionVisible)
        let stored = KeychainStorage.shared.syncInterval
        let validValues = [0, 1, 3, 5, 7]
        _syncIntervalIndex = State(initialValue: Double(validValues.firstIndex(of: stored) ?? 0))
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 20) {
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
                    .padding(.bottom, 4)
                    .staggeredEntrance(0, animate: animateContent)

                    // MARK: Reminders Card
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

                            Toggle(isOn: $isReminderSyncEnabled) {
                                Text(L10n.enableSync)
                                    .font(.callout)
                            }
                            .toggleStyle(.switch)
                            .onChange(of: isReminderSyncEnabled) { enabled in
                                handleReminderSyncToggle(enabled)
                            }

                            if !reminderAccessDescription.isEmpty {
                                Text(reminderAccessDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .staggeredEntrance(1, animate: animateContent)

                    // MARK: Sync Interval Card
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                Text(L10n.syncInterval)
                                    .font(.headline)
                            }

                            Slider(value: $syncIntervalIndex, in: 0...4, step: 1)

                            Text(L10n.syncIntervalDescription(syncValues[Int(syncIntervalIndex)]))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .contentTransition(.opacity)
                                .animation(.default, value: syncIntervalIndex)
                        }
                    }
                    .staggeredEntrance(2, animate: animateContent)
                    .onChange(of: syncIntervalIndex) { _ in
                        let value = syncValues[Int(syncIntervalIndex)]
                        KeychainStorage.shared.syncInterval = value
                    }

                    // MARK: Launch at Login Card
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

                            Toggle(isOn: $isLaunchAtLoginEnabled) {
                                Text(L10n.launchAtLoginToggle)
                                    .font(.callout)
                            }
                            .toggleStyle(.switch)
                            .onChange(of: isLaunchAtLoginEnabled) { enabled in
                                handleLaunchAtLoginToggle(enabled)
                            }

                            Text(L10n.launchAtLoginDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .staggeredEntrance(3, animate: animateContent)

                    // MARK: Completed Section Card
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

                            Toggle(isOn: $isCompletedSectionVisible) {
                                Text(L10n.showCompletedSectionDescription)
                                    .font(.callout)
                            }
                            .toggleStyle(.switch)
                            .onChange(of: isCompletedSectionVisible) { visible in
                                KeychainStorage.shared.isCompletedSectionVisible = visible
                            }
                        }
                    }
                    .staggeredEntrance(4, animate: animateContent)

                    // MARK: Database Auth Card
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "archivebox.fill")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                Text(L10n.databaseAccess)
                                    .font(.headline)
                                Spacer()
                                StatusPill(
                                    icon: isAuthorized ? "checkmark" : "exclamationmark",
                                    text: isAuthorized ? L10n.authorized : L10n.notAuthorized,
                                    color: isAuthorized ? .green : .orange
                                )
                                .animation(.default, value: isAuthorized)
                            }

                            Text(isAuthorized
                                 ? L10n.accessGranted
                                 : L10n.accessNotGranted)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Button {
                                requestBookmark()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: isAuthorized ? "arrow.clockwise" : "lock.open.fill")
                                    Text(isAuthorized ? L10n.reauthorize : L10n.authorizeAccess)
                                }
                                .font(.callout)
                                .fontWeight(.medium)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                        }
                    }
                    .staggeredEntrance(5, animate: animateContent)

                    // MARK: Language Card
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "globe")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                Text(L10n.language)
                                    .font(.headline)
                            }

                            Picker("", selection: $language) {
                                ForEach(Language.allCases, id: \.self) { lang in
                                    Text(lang.displayName).tag(lang)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .staggeredEntrance(6, animate: animateContent)

                    Spacer(minLength: 4)

                    // GitHub Link
                    Link(destination: URL(string: "https://github.com/ECHOUniverse/BearTodoMenuBar")!) {
                        Image(nsImage: Self.gitHubIcon)
                            .resizable()
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .staggeredEntrance(7, animate: animateContent)

                    Spacer(minLength: 8)
                }
                .padding(24)

            }
            .frame(width: 420)
            .onAppear {
                isAuthorized = BearBookmarkManager.shared.hasBookmark
            reminderAccessStatus = EKEventStore.authorizationStatus(for: .reminder)
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApp.windows where window.title == L10n.settings {
                    window.level = .floating
                    break
                }
            }
        }
    }

    private static var gitHubIcon: NSImage = {
        guard let url = Bundle.module.url(forResource: "github-mark", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
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

    // MARK: - Actions

    private func handleReminderSyncToggle(_ enabled: Bool) {
        KeychainStorage.shared.isReminderSyncEnabled = enabled
        if enabled {
            Task {
                let granted = await ReminderService.shared.requestAccess()
                await MainActor.run {
                    reminderAccessStatus = EKEventStore.authorizationStatus(for: .reminder)
                    if !granted {
                        isReminderSyncEnabled = false
                        KeychainStorage.shared.isReminderSyncEnabled = false
                        errorMessage = L10n.reminderAccessDenied
                        showError = true
                    }
                }
            }
        } else {
            reminderAccessStatus = EKEventStore.authorizationStatus(for: .reminder)
        }
    }

    private func handleLaunchAtLoginToggle(_ enabled: Bool) {
        if enabled {
            do {
                try SMAppService.mainApp.register()
                KeychainStorage.shared.isLaunchAtLoginEnabled = true
            } catch {
                isLaunchAtLoginEnabled = false
                errorMessage = error.localizedDescription
                showError = true
            }
        } else {
            do {
                try SMAppService.mainApp.unregister()
                KeychainStorage.shared.isLaunchAtLoginEnabled = false
            } catch {
                isLaunchAtLoginEnabled = true
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

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