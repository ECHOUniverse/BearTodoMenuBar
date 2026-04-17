import SwiftUI
import AppKit

struct SettingsView: View {
    @State private var token: String = ""
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isAuthorized: Bool = false

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
        .frame(width: 400, height: 320)
        .onAppear {
            token = KeychainStorage.shared.token ?? ""
            isAuthorized = BearBookmarkManager.shared.hasBookmark
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
