import SwiftUI
import AppKit
import EventKit

struct SettingsView: View {
    @State private var token: String = ""
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isAuthorized: Bool = false
    @State private var isReminderSyncEnabled: Bool = false
    @State private var reminderAccessStatus: EKAuthorizationStatus = .notDetermined

    var onClose: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bear API Token")
                .font(.title2)
                .fontWeight(.semibold)

            Text("请在 Bear 应用中选择 Help → API Token 获取你的个人 Token。")
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            SecureField("输入 API Token", text: $token)
                .textFieldStyle(.roundedBorder)

            Divider()

            Text("同步到系统提醒事项")
                .font(.title3)
                .fontWeight(.semibold)

            Toggle(isOn: $isReminderSyncEnabled) {
                Text("启用同步")
            }
            .onChange(of: isReminderSyncEnabled) { enabled in
                handleReminderSyncToggle(enabled)
            }

            HStack {
                Image(systemName: reminderAccessIcon)
                    .foregroundColor(reminderAccessColor)
                Text(reminderAccessText)
                    .font(.callout)
                    .foregroundColor(.secondary)
                Spacer()
            }

            Divider()

            Text("数据库访问授权")
                .font(.title3)
                .fontWeight(.semibold)

            HStack {
                Image(systemName: isAuthorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(isAuthorized ? .green : .orange)
                Text(isAuthorized ? "已授权自动刷新" : "未授权，自动刷新不可用")
                    .foregroundColor(.secondary)
                Spacer()
            }

            Button(isAuthorized ? "重新授权" : "授权访问 Bear 数据库") {
                requestBookmark()
            }

            Spacer()

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
        .padding()
        .frame(width: 400, height: 400)
        .onAppear {
            token = KeychainStorage.shared.token ?? ""
            isAuthorized = BearBookmarkManager.shared.hasBookmark
            isReminderSyncEnabled = KeychainStorage.shared.isReminderSyncEnabled
            reminderAccessStatus = EKEventStore.authorizationStatus(for: .reminder)
        }
        .overlay {
            if showSuccess {
                Text("保存成功")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .transition(.opacity)
            }
        }
        .alert("保存失败", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var reminderAccessIcon: String {
        if reminderAccessStatus == .authorized {
            return "checkmark.circle.fill"
        } else if reminderAccessStatus == .denied || reminderAccessStatus == .restricted {
            return "xmark.circle.fill"
        } else {
            return "exclamationmark.triangle.fill"
        }
    }

    private var reminderAccessColor: Color {
        if reminderAccessStatus == .authorized {
            return .green
        } else if reminderAccessStatus == .denied || reminderAccessStatus == .restricted {
            return .red
        } else {
            return .orange
        }
    }

    private var reminderAccessText: String {
        if reminderAccessStatus == .authorized {
            return "已获取提醒事项权限"
        } else if reminderAccessStatus == .denied {
            return "权限已被拒绝，请前往系统设置开启"
        } else if reminderAccessStatus == .restricted {
            return "权限受限制，无法访问提醒事项"
        } else if reminderAccessStatus == .notDetermined {
            return "尚未请求权限"
        } else {
            return "未知状态"
        }
    }

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

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showSuccess = false
            onClose?()
        }
    }
}
