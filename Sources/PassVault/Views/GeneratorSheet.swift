import PassVaultCore
import SwiftUI

/// 密码生成器弹窗。passwordBinding 非 nil 时（编辑表单内）提供「使用此密码」；
/// 独立打开时提供「复制」。
struct GeneratorSheet: View {
    let initialPassword: String
    var passwordBinding: Binding<String>?

    @Environment(\.dismiss) private var dismiss
    @State private var length: Double = 20
    @State private var uppercase = true
    @State private var lowercase = true
    @State private var digits = true
    @State private var symbols = true
    @State private var excludeAmbiguous = true
    @State private var generated = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("密码生成器")
                .font(.headline)

            HStack {
                Text(generated.isEmpty ? "—" : generated)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                Button {
                    regenerate()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("重新生成")
            }
            .padding(.horizontal, 12)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("长度")
                        .frame(width: 40, alignment: .leading)
                    Slider(value: $length, in: 8...64, step: 1)
                    Text("\(Int(length))")
                        .monospacedDigit()
                        .frame(width: 30, alignment: .trailing)
                }
                HStack(spacing: 14) {
                    Toggle("大写字母", isOn: $uppercase).toggleStyle(.checkbox)
                    Toggle("小写字母", isOn: $lowercase).toggleStyle(.checkbox)
                    Toggle("数字", isOn: $digits).toggleStyle(.checkbox)
                    Toggle("符号", isOn: $symbols).toggleStyle(.checkbox)
                }
                Toggle("排除易混淆字符（0 O 1 l I）", isOn: $excludeAmbiguous)
                    .toggleStyle(.checkbox)
            }

            if generated.isEmpty && !hasAnySet {
                Text("请至少选择一种字符类型")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("关闭", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                if passwordBinding != nil {
                    Button("使用此密码") {
                        passwordBinding?.wrappedValue = generated
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(generated.isEmpty)
                } else {
                    Button("复制") {
                        ClipboardService.copySensitive(generated, clearAfter: 30)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(generated.isEmpty)
                }
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear {
            if !initialPassword.isEmpty {
                // 从已有密码推断选项
                length = Double(max(min(initialPassword.count, 64), 8))
                uppercase = initialPassword.contains { $0.isUppercase }
                lowercase = initialPassword.contains { $0.isLowercase }
                digits = initialPassword.contains { $0.isNumber }
                symbols = initialPassword.contains { !$0.isLetter && !$0.isNumber }
            }
            regenerate()
        }
        .onChange(of: length) { _, _ in regenerate() }
        .onChange(of: uppercase) { _, _ in regenerate() }
        .onChange(of: lowercase) { _, _ in regenerate() }
        .onChange(of: digits) { _, _ in regenerate() }
        .onChange(of: symbols) { _, _ in regenerate() }
        .onChange(of: excludeAmbiguous) { _, _ in regenerate() }
    }

    private var hasAnySet: Bool { uppercase || lowercase || digits || symbols }

    private func regenerate() {
        let options = PasswordGenerator.Options(
            length: Int(length),
            uppercase: uppercase,
            lowercase: lowercase,
            digits: digits,
            symbols: symbols,
            excludeAmbiguous: excludeAmbiguous
        )
        generated = PasswordGenerator.generate(options: options)
    }
}
