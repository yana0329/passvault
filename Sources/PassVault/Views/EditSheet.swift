import PassVaultCore
import SwiftUI

/// 新建/编辑表单草稿（明文，仅在内存中短暂存在，保存时统一加密）
struct ItemDraft {
    var category: ItemCategory = .other
    var customCategoryId: UUID?
    var title = ""
    var username = ""
    var url = ""
    var host = ""
    var port = ""
    var dbType = DatabaseKind.all[0]
    var dbName = ""
    var password = ""
    var notes = ""
    var tags = ""
    var favorite = false

    init() {}

    init(item: CredentialItem, fields: AppState.DecryptedFields) {
        category = item.category
        customCategoryId = item.customCategoryId
        title = item.title
        username = item.username
        url = item.url ?? ""
        host = item.host ?? ""
        port = item.port.map(String.init) ?? ""
        dbType = item.dbType ?? DatabaseKind.all[0]
        dbName = item.dbName ?? ""
        password = fields.password
        notes = fields.notes
        tags = item.tags
        favorite = item.favorite
    }
}

struct EditSheet: View {
    let original: CredentialItem?

    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ItemDraft()
    @State private var showPassword = false
    @State private var showGenerator = false
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(original == nil ? "新建条目" : "编辑条目")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Form {
                Section {
                    Picker("分类", selection: $draft.category) {
                        ForEach(ItemCategory.allCases) { category in
                            Text(category.label).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                    if !state.categories.isEmpty {
                        Picker("自定义分组", selection: $draft.customCategoryId) {
                            Text("无").tag(UUID?.none)
                            ForEach(state.categories) { category in
                                Text(category.name).tag(UUID?.some(category.id))
                            }
                        }
                    }
                }

                Section("账号") {
                    TextField("标题（必填）", text: $draft.title)
                    TextField("用户名 / 账号", text: $draft.username)
                    passwordSection
                }

                Section("连接信息") {
                    dynamicFields
                }

                Section("其他") {
                    TextField("标签（用逗号分隔，如：工作,生产）", text: $draft.tags)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("备注（加密存储）")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $draft.notes)
                            .font(.body)
                            .frame(minHeight: 64)
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                    }
                    Toggle("收藏", isOn: $draft.favorite)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("取消", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(original == nil ? "添加" : "保存") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
        }
        .frame(width: 480)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let original {
                draft = ItemDraft(item: original, fields: state.decryptedFields(original))
            }
        }
        .sheet(isPresented: $showGenerator) {
            GeneratorSheet(initialPassword: draft.password, passwordBinding: $draft.password)
        }
    }

    @ViewBuilder
    private var passwordSection: some View {
        HStack(spacing: 8) {
            if showPassword {
                TextField("密码", text: $draft.password)
                    .font(.system(.body, design: .monospaced))
            } else {
                SecureField("密码", text: $draft.password)
            }
            Button(showPassword ? "隐藏" : "显示") { showPassword.toggle() }
                .controlSize(.small)
            Button("生成…") { showGenerator = true }
                .controlSize(.small)
        }
        if !draft.password.isEmpty {
            HStack {
                Text("强度：\(PasswordGenerator.strengthLabel(draft.password))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var dynamicFields: some View {
        switch draft.category {
        case .browser:
            TextField("网址（如 github.com）", text: $draft.url)
        case .server:
            TextField("主机 / IP（必填）", text: $draft.host)
            TextField("端口（默认 22）", text: $draft.port)
        case .database:
            Picker("数据库类型", selection: $draft.dbType) {
                ForEach(DatabaseKind.all, id: \.self) { kind in
                    Text(kind).tag(kind)
                }
            }
            TextField("主机 / IP", text: $draft.host)
            TextField("端口", text: $draft.port)
            TextField("数据库名（如 orders_db）", text: $draft.dbName)
        case .other:
            Text("该分类暂无附加字段，可在备注中补充")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func save() {
        state.save(draft, editing: original)
        dismiss()
    }
}
