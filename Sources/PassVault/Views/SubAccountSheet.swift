import PassVaultCore
import SwiftUI

/// 详情页打开附加账号编辑弹窗的上下文
struct SubAccountTarget: Identifiable {
    let id = UUID()
    let itemId: UUID
    let itemTitle: String
    let original: SubAccount?
}

/// 新增/编辑条目下的附加账号
struct SubAccountSheet: View {
    let itemId: UUID
    let itemTitle: String
    let original: SubAccount?

    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var note = ""
    @State private var showPassword = false
    @State private var showGenerator = false
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 14) {
            Text(original == nil ? "添加账号" : "编辑账号")
                .font(.headline)
            Text("「\(itemTitle)」下的账号")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Form {
                TextField("用户名 / 账号", text: $username)
                HStack(spacing: 8) {
                    if showPassword {
                        TextField("密码", text: $password)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField("密码", text: $password)
                    }
                    Button(showPassword ? "隐藏" : "显示") { showPassword.toggle() }
                        .controlSize(.small)
                    Button("生成…") { showGenerator = true }
                        .controlSize(.small)
                }
                TextField("备注（可选，如：工作账号）", text: $note)
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("取消", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(original == nil ? "添加" : "保存") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(username.isEmpty && password.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let original {
                username = original.username
                note = original.note
                password = state.decryptedAccountPassword(original)
            }
        }
        .sheet(isPresented: $showGenerator) {
            GeneratorSheet(initialPassword: password, passwordBinding: $password)
        }
    }

    private func save() {
        state.saveSubAccount(itemId: itemId, original: original, username: username, password: password, note: note)
        dismiss()
    }
}
