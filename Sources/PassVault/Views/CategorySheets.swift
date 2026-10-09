import PassVaultCore
import SwiftUI

/// 分类重命名弹窗（设置页与侧栏右键共用）
struct RenameCategorySheet: View {
    let category: CustomCategory

    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        VStack(spacing: 14) {
            Text("重命名分类")
                .font(.headline)
            TextField("分类名称", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit { commit() }
            HStack {
                Spacer()
                Button("取消", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存") { commit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear { name = category.name }
    }

    private func commit() {
        state.renameCategory(category, to: name)
        dismiss()
    }
}
