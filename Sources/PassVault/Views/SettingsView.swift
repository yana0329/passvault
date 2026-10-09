import PassVaultCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var state
    @State private var newCategoryName = ""
    @State private var csvImportPreview: CSVImportPreview?
    @State private var backupPasswordSheet: BackupPasswordContext?
    @State private var renameTarget: CustomCategory?
    @State private var deleteCandidate: CustomCategory?
    @State private var showDeleteConfirm = false
    @State private var showDuplicateScan = false

    struct CSVImportPreview: Identifiable {
        let id = UUID()
        let rows: [ImportedRow]
    }

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("通用", systemImage: "gearshape") }
            categoriesTab
                .tabItem { Label("分类", systemImage: "folder") }
            dataTab
                .tabItem { Label("数据", systemImage: "externaldrive") }
        }
        .sheet(item: $csvImportPreview) { preview in
            CSVImportSheet(rows: preview.rows)
        }
        .sheet(item: $backupPasswordSheet) { context in
            BackupPasswordSheet(mode: context.mode)
        }
        .sheet(isPresented: $showDuplicateScan) {
            DuplicateScanSheet()
        }
    }

    // MARK: - 通用

    private var generalTab: some View {
        @Bindable var settings = state.settings
        return Form {
            Section {
                Picker("密码显示", selection: $settings.revealAllAfterUnlock) {
                    Text("逐条显示（默认）").tag(false)
                    Text("解锁后统一显示").tag(true)
                }
                .help("统一显示：认证通过后，所有条目的密码直接明文显示，无需逐条点击；也可用工具栏的眼睛按钮临时开关")
                Picker("自动锁定", selection: $settings.autoLockMinutes) {
                    ForEach(AppSettings.autoLockChoices, id: \.value) { choice in
                        Text(choice.label).tag(choice.value)
                    }
                }
                .help("电脑空闲超过该时长后，自动隐藏已显示的密码并要求重新认证")
                Picker("认证缓存", selection: $settings.authCacheMinutes) {
                    ForEach(AppSettings.authCacheChoices, id: \.value) { choice in
                        Text(choice.label).tag(choice.value)
                    }
                }
                .help("认证通过后，该时长内再次查看/复制密码无需重复认证")
                Picker("剪贴板清除", selection: $settings.clipboardClearSeconds) {
                    ForEach(AppSettings.clipboardChoices, id: \.value) { choice in
                        Text(choice.label).tag(choice.value)
                    }
                }
                .help("复制密码后延时自动清除剪贴板")
            } footer: {
                Text("查看密码使用 Touch ID\(AuthService.biometryLabel.map { "（当前可用：\($0)）" } ?? "")，不可用时自动回退系统登录密码。\n选择「解锁后统一显示」时，密码明文的可见时长跟随「认证缓存」设置，锁定或过期后自动恢复掩码；仅建议在私密环境使用。")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - 分类

    private var categoriesTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section("自定义分类") {
                    if state.categories.isEmpty {
                        Text("暂无自定义分类。内置分类（浏览器 / 服务器 / 数据库 / 其他）固定显示；添加的自定义分类会出现在侧栏、编辑表单和 CSV 导入中。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(state.categories) { category in
                            HStack {
                                Image(systemName: "folder")
                                    .foregroundStyle(.purple)
                                Text(category.name)
                                Spacer()
                                Text("\(state.count(for: .custom(category.id))) 条")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .monospacedDigit()
                                Button {
                                    renameTarget = category
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.borderless)
                                .help("重命名")
                                Button {
                                    deleteCandidate = category
                                    showDeleteConfirm = true
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .help("删除该分类（不影响条目本身）")
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                TextField("新分类名称", text: $newCategoryName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addCategory)
                Button("添加") { addCategory() }
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .sheet(item: $renameTarget) { category in
            RenameCategorySheet(category: category)
        }
        .confirmationDialog("删除分类", isPresented: $showDeleteConfirm, presenting: deleteCandidate) { category in
            Button("删除「\(category.name)」", role: .destructive) {
                state.deleteCategory(category)
            }
        } message: { category in
            Text("该分类下有 \(state.count(for: .custom(category.id))) 条记录。删除后这些记录将变为「未分组」，条目本身不会被删除。")
        }
    }

    private func addCategory() {
        state.addCategory(newCategoryName)
        newCategoryName = ""
    }

    // MARK: - 数据

    private var dataTab: some View {
        Form {
            Section("整理") {
                HStack {
                    Button("合并同标题条目…") {
                        showDuplicateScan = true
                    }
                    Spacer()
                }
                Text("扫描同分类下标题相同（忽略大小写）的活动条目，合并为一个：账号归入保留条目的附加账号列表，其余条目移入回收站。适合整理导入产生的重复条目。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("备份") {
                HStack {
                    Button("导出加密备份…") {
                        if let url = FileDialog.chooseSaveLocation(title: "导出加密备份", defaultName: "passvault-备份.pvbak") {
                            backupPasswordSheet = BackupPasswordContext(mode: .export(url))
                        }
                    }
                    Spacer()
                }
                Text("备份文件用你设置的「备份密码」加密（PBKDF2 + AES-256-GCM），用于换机恢复或防灾。主密钥绑定本机钥匙串，不带备份文件换机后数据无法恢复。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("从备份恢复…") {
                        if let url = FileDialog.chooseFile(title: "选择备份文件") {
                            backupPasswordSheet = BackupPasswordContext(mode: .importFile(url))
                        }
                    }
                    Spacer()
                }
                Text("恢复时记录会全部作为新增条目导入，不会覆盖现有数据。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("导入 CSV") {
                HStack {
                    Button("从 CSV 导入…") {
                        if let url = FileDialog.chooseFile(title: "选择 CSV 文件") {
                            importCSV(from: url)
                        }
                    }
                    Spacer()
                }
                Text("支持 Chrome「设置 → 密码管理工具 → 导出密码」生成的 CSV、Bitwarden/1Password 导出的 CSV，以及常见中文表头。重复条目（标题+用户名相同）自动跳过。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func importCSV(from url: URL) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let rows = CSVImporter.map(rows: CSVParser.parse(text))
            guard !rows.isEmpty else {
                state.showToast("未能从该文件解析出任何记录")
                return
            }
            csvImportPreview = CSVImportPreview(rows: rows)
        } catch {
            state.showToast("读取文件失败：\(error.localizedDescription)")
        }
    }
}

// MARK: - CSV 导入确认

private struct CSVImportSheet: View {
    let rows: [ImportedRow]

    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var category: ItemCategory = .other
    @State private var customCategoryId: UUID?

    var body: some View {
        VStack(spacing: 14) {
            Text("导入 CSV")
                .font(.headline)
            Text("共解析出 \(rows.count) 条记录，将导入到以下分类：")
                .foregroundStyle(.secondary)
            Form {
                Picker("分类", selection: $category) {
                    ForEach(ItemCategory.allCases) { c in
                        Text(c.label).tag(c)
                    }
                }
                if !state.categories.isEmpty {
                    Picker("自定义分组", selection: $customCategoryId) {
                        Text("无").tag(UUID?.none)
                        ForEach(state.categories) { c in
                            Text(c.name).tag(UUID?.some(c.id))
                        }
                    }
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("取消", role: .cancel) { dismiss() }
                Button("导入") {
                    state.importRows(rows, category: category, customCategoryId: customCategoryId)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}

// MARK: - 备份密码输入

struct BackupPasswordContext: Identifiable {
    enum Mode { case export(URL); case importFile(URL) }
    let id = UUID()
    let mode: Mode
}

private struct BackupPasswordSheet: View {
    let mode: BackupPasswordContext.Mode

    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirm = ""
    @State private var errorText: String?
    @State private var working = false

    var body: some View {
        VStack(spacing: 14) {
            Text(isExport ? "设置备份密码" : "输入备份密码")
                .font(.headline)
            Text(isExport
                 ? "备份密码用于加密备份文件，请务必牢记——忘记备份密码将无法恢复数据。"
                 : "输入导出该备份文件时设置的密码。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            SecureField("备份密码", text: $password)
                .textFieldStyle(.roundedBorder)
            if isExport {
                SecureField("再次输入确认", text: $confirm)
                    .textFieldStyle(.roundedBorder)
            }
            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("取消", role: .cancel) { dismiss() }
                Button(isExport ? "导出" : "恢复") { run() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(password.isEmpty || working || (isExport && password != confirm))
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    private var isExport: Bool {
        if case .export = mode { return true }
        return false
    }

    private func run() {
        working = true
        errorText = nil
        switch mode {
        case .export(let url):
            _ = state.exportBackup(password: password, to: url)
            dismiss()
        case .importFile(let url):
            Task { @MainActor in
                // PBKDF2 派生较耗时，先让 UI 呈现"处理中"状态
                try? await Task.sleep(nanoseconds: 50_000_000)
                do {
                    let payload = try BackupService.importBackup(from: url, password: password)
                    state.importBackup(payload)
                    dismiss()
                } catch {
                    errorText = error.localizedDescription
                    working = false
                }
            }
        }
    }
}
