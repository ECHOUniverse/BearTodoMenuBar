import SwiftUI
import AppKit
import EventKit

// MARK: - Liquid Glass Card

struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
            )
    }
}

// MARK: - Status Pill

struct StatusPill: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @State private var token: String = ""
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage: String = ""
    @State private var isAuthorized: Bool = false
    @State private var isReminderSyncEnabled: Bool = false
    @State private var reminderAccessStatus: EKAuthorizationStatus = .notDetermined

    var onClose: (() -> Void)?

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("设置")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("配置 Bear 待办同步选项")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)

                    // MARK: API Token Card
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "key.fill")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                Text("Bear API Token")
                                    .font(.headline)
                            }

                            Text("在 Bear 应用中选择 Help → API Token 获取你的个人 Token。")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            SecureField("输入 API Token", text: $token)
                                .textFieldStyle(.plain)
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color(nsColor: .textBackgroundColor).opacity(0.6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                                )
                        }
                    }

                    // MARK: Reminders Card
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "bell.fill")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                Text("系统提醒事项")
                                    .font(.headline)
                                Spacer()
                                StatusPill(
                                    icon: reminderAccessIcon,
                                    text: reminderAccessTextShort,
                                    color: reminderAccessColor
                                )
                            }

                            Toggle(isOn: $isReminderSyncEnabled) {
                                Text("启用同步")
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

                    // MARK: Database Auth Card
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "archivebox.fill")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                Text("数据库访问授权")
                                    .font(.headline)
                                Spacer()
                                StatusPill(
                                    icon: isAuthorized ? "checkmark" : "exclamationmark",
                                    text: isAuthorized ? "已授权" : "未授权",
                                    color: isAuthorized ? .green : .orange
                                )
                            }

                            Text(isAuthorized
                                 ? "已授权访问 Bear 数据库，自动刷新可用。"
                                 : "未授权访问 Bear 数据库，自动刷新功能不可用。")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Button {
                                requestBookmark()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: isAuthorized ? "arrow.clockwise" : "lock.open.fill")
                                    Text(isAuthorized ? "重新授权" : "授权访问")
                                }
                                .font(.callout)
                                .fontWeight(.medium)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                        }
                    }

                    Spacer(minLength: 8)

                    // Bottom Actions
                    HStack {
                        Spacer()

                        Button("取消") {
                            onClose?()
                        }
                        .keyboardShortcut(.cancelAction)

                        Button("保存") {
                            saveToken()
                        }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(24)
            }

            // Success Toast
            if showSuccess {
                VStack {
                    Spacer()
                    Text("保存成功")
                        .font(.callout)
                        .fontWeight(.medium)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    Spacer().frame(height: 24)
                }
            }
        }
        .frame(minWidth: 420, maxWidth: .infinity, minHeight: 480, maxHeight: .infinity)
        .onAppear {
            token = KeychainStorage.shared.token ?? ""
            isAuthorized = BearBookmarkManager.shared.hasBookmark
            isReminderSyncEnabled = KeychainStorage.shared.isReminderSyncEnabled
            reminderAccessStatus = EKEventStore.authorizationStatus(for: .reminder)
        }
        .alert("保存失败", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Reminder Access Helpers

    private var reminderAccessIcon: String {
        switch reminderAccessStatus {
        case .authorized: return "checkmark"
        case .denied, .restricted: return "xmark"
        default: return "exclamationmark"
        }
    }

    private var reminderAccessColor: Color {
        switch reminderAccessStatus {
        case .authorized: return .green
        case .denied, .restricted: return .red
        default: return .orange
        }
    }

    private var reminderAccessTextShort: String {
        switch reminderAccessStatus {
        case .authorized: return "已允许"
        case .denied: return "已拒绝"
        case .restricted: return "受限制"
        case .notDetermined: return "待授权"
        default: return "未知"
        }
    }

    private var reminderAccessDescription: String {
        switch reminderAccessStatus {
        case .authorized:
            return "提醒事项权限已获取，待办将自动同步到系统提醒事项。"
        case .denied:
            return "权限已被拒绝，请前往系统设置 → 隐私与安全性 → 提醒事项中开启。"
        case .restricted:
            return "权限受限制，无法访问提醒事项。"
        case .notDetermined:
            return "开启开关后将请求提醒事项权限。"
        default:
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
                        errorMessage = "无法访问提醒事项，请检查系统权限设置"
                        showError = true
                    }
                }
            }
        } else {
            reminderAccessStatus = EKEventStore.authorizationStatus(for: .reminder)
        }
    }

    private func requestBookmark() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "授权访问"
        panel.message = "请选择 Bear 的 Application Data 目录"

        if let dbURL = BearFileWatcher.findBearDatabasePath() {
            panel.directoryURL = dbURL.deletingLastPathComponent()
        } else {
            let groupContainersURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Group Containers")
            panel.directoryURL = groupContainersURL
        }

        panel.beginSheetModal(for: NSApp.keyWindow!) { result in
            if result == .OK, let url = panel.url {
                if BearBookmarkManager.shared.saveBookmark(for: url) {
                    isAuthorized = true
                    NotificationCenter.default.post(name: .bearDatabaseAccessGranted, object: nil)
                } else {
                    errorMessage = "保存授权失败"
                    showError = true
                }
            }
        }
    }

    private func saveToken() {
        guard !token.isEmpty else {
            errorMessage = "Token 不能为空"
            showError = true
            return
        }

        KeychainStorage.shared.token = token
        showSuccess = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showSuccess = false
            onClose?()
        }
    }
}
