import SwiftUI

struct SettingsView: View {
    @State private var token: String = ""
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""

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
        .frame(width: 400, height: 200)
        .onAppear {
            token = KeychainStorage.shared.token ?? ""
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
