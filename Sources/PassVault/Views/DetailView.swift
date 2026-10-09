import PassVaultCore
import SwiftUI

struct DetailView: View {
    @Environment(AppState.self) private var state
    @State private var editTarget: EditTarget?
    @State private var notesRevealedFor: UUID?
    @State private var confirmDeleteForever = false
    @State private var subAccountTarget: SubAccountTarget?
    @State private var pendingDeleteAccount: SubAccount?
    @State private var showDeleteAccountConfirm = false
    @State private var mergeRequest: MergeRequest?

    var body: some View {
        Group {
            if let item = state.selectedItem {
                content(for: item)
            } else if state.multiSelectedCount > 1 {
                ContentUnavailableView {
                    Label("已选中 \(state.multiSelectedCount) 个条目", systemImage: "checklist")
                } description: {
                    Text("可将所选条目合并为一个：各条目的账号将归入保留条目的附加账号列表，其余条目移入回收站。")
                } actions: {
                    Button("合并…") {
                        mergeRequest = MergeRequest(items: state.multiSelectedItems)
                    }
                }
            } else {
                ContentUnavailableView(
                    "未选择条目",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("从中间的列表选择一个条目查看详情；按住 ⌘ 点选可多选合并")
                )
            }
        }
        // sheet 统一挂在最外层：无论当前渲染哪个分支，点合并都能立即弹出
        .sheet(item: $editTarget) { target in
            EditSheet(original: target.original)
        }
        .sheet(item: $subAccountTarget) { target in
            SubAccountSheet(itemId: target.itemId, itemTitle: target.itemTitle, original: target.original)
        }
        .sheet(item: $mergeRequest) { request in
            MergeSheet(request: request)
        }
    }

    // MARK: - 内容

    private func content(for item: CredentialItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(for: item)
                fieldsSection(for: item)
                accountsSection(for: item)
                notesSection(for: item)
                metaSection(for: item)
                if item.deletedAt != nil {
                    trashActions(for: item)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { state.reloadSelectedAccounts() }
        .onChange(of: item.id) { _, _ in
            notesRevealedFor = nil
            state.reloadSelectedAccounts()
        }
        .confirmationDialog("删除账号", isPresented: $showDeleteAccountConfirm, presenting: pendingDeleteAccount) { account in
            Button("删除「\(account.username)」", role: .destructive) {
                state.deleteSubAccount(account)
            }
        } message: { account in
            Text("将从「\(item.title)」中删除该组账号，操作不可恢复。")
        }
    }

    private func header(for item: CredentialItem) -> some View {
        HStack(alignment: .center, spacing: 14) {
            CategoryBadge(category: item.category, size: 46)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title.isEmpty ? "（未命名）" : item.title)
                    .font(.title2.weight(.semibold))
                HStack(spacing: 8) {
                    Text(categoryName(for: item))
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(item.category.color.opacity(0.15), in: Capsule())
                        .foregroundStyle(item.category.color)
                    if item.deletedAt != nil {
                        Text("回收站")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.red.opacity(0.12), in: Capsule())
                            .foregroundStyle(.red)
                    }
                }
            }
            Spacer()
            Button {
                state.toggleFavorite(item)
            } label: {
                Image(systemName: item.favorite ? "star.fill" : "star")
                    .foregroundStyle(item.favorite ? .yellow : .secondary)
            }
            .help(item.favorite ? "取消收藏" : "收藏")
            if item.deletedAt == nil {
                Button("编辑") {
                    editTarget = EditTarget(original: item)
                }
            }
        }
    }

    private func categoryName(for item: CredentialItem) -> String {
        var label = item.category.label
        if let customId = item.customCategoryId,
           let custom = state.categories.first(where: { $0.id == customId }) {
            label += " · " + custom.name
        }
        return label
    }

    // MARK: - 字段

    private func fieldsSection(for item: CredentialItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("账号信息")
                .font(.headline)
                .padding(.bottom, 4)

            fieldRow("分类") {
                HStack(spacing: 6) {
                    Image(systemName: item.category.symbolName)
                        .foregroundStyle(item.category.color)
                    Text(categoryName(for: item))
                }
            }
            Divider()
            fieldRow("用户名") {
                valueWithCopy(item.username) { state.copyUsername(item) }
            }
            Divider()
            passwordRow(for: item)
            Divider()
            if let url = item.url, !url.isEmpty {
                fieldRow("网址") {
                    HStack(spacing: 4) {
                        Text(url).lineLimit(1).truncationMode(.middle)
                        Button {
                            openInBrowser(url)
                        } label: {
                            Image(systemName: "arrow.up.forward.app")
                        }
                        .buttonStyle(.borderless)
                        .help("在浏览器中打开")
                    }
                }
                Divider()
            }
            if let host = item.host, !host.isEmpty {
                fieldRow(item.category == .database ? "主机" : "主机 / IP") {
                    valueWithCopy(host) { ClipboardService.copyPlain(host) }
                }
                Divider()
            }
            if item.port != nil {
                fieldRow("端口") { Text("\(item.port!)") }
                Divider()
            }
            if let dbType = item.dbType, item.category == .database {
                fieldRow("数据库类型") { Text(dbType) }
                Divider()
            }
            if let dbName = item.dbName, item.category == .database, !dbName.isEmpty {
                fieldRow("数据库名") {
                    valueWithCopy(dbName) { ClipboardService.copyPlain(dbName) }
                }
                Divider()
            }
            if !item.tagList.isEmpty {
                fieldRow("标签") {
                    HStack(spacing: 6) {
                        ForEach(item.tagList, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                }
                Divider()
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func passwordRow(for item: CredentialItem) -> some View {
        let revealed = state.isPasswordVisible(item)
        let password = revealed ? state.decryptedFields(item).password : ""
        fieldRow("密码") {
            HStack(spacing: 8) {
                if revealed {
                    Text(password.isEmpty ? "（空）" : password)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text(item.passwordEnc.isEmpty ? "未设置" : "••••••••••••")
                        .foregroundStyle(.secondary)
                        .font(.system(.body, design: .monospaced))
                }
                Spacer()
                if state.passwordGloballyVisible {
                    Text("统一显示中")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else if revealed {
                    Button {
                        state.conceal(item)
                    } label: {
                        Image(systemName: "eye.slash")
                    }
                    .help("隐藏密码")
                } else {
                    Button {
                        Task { await state.reveal(item) }
                    } label: {
                        Image(systemName: "eye")
                    }
                    .disabled(item.passwordEnc.isEmpty)
                    .help("显示密码（需要 Touch ID 或系统密码）")
                }
                Button {
                    Task { await state.copyPassword(item) }
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .disabled(item.passwordEnc.isEmpty)
                .help("复制密码（需要认证，复制后自动清除剪贴板）")
            }
        }
    }

    // MARK: - 附加账号

    private func accountsSection(for item: CredentialItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("附加账号（\(state.selectedAccounts.count)）")
                    .font(.headline)
                Spacer()
                if item.deletedAt == nil {
                    Button {
                        subAccountTarget = SubAccountTarget(itemId: item.id, itemTitle: item.title, original: nil)
                    } label: {
                        Label("添加账号", systemImage: "plus")
                    }
                    .controlSize(.small)
                }
            }
            if state.selectedAccounts.isEmpty {
                if item.deletedAt == nil {
                    Text("同一标题下可保存多组账号密码（例如同一网站的多个账号），与上方主账号相互独立。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(state.selectedAccounts) { account in
                    accountRow(account, itemTitle: item.title)
                }
            }
        }
        .padding(.top, 8)
    }

    private func accountRow(_ account: SubAccount, itemTitle: String) -> some View {
        let visible = state.isAccountVisible(account)
        let password = visible ? state.decryptedAccountPassword(account) : ""
        return HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(account.username.isEmpty ? "（未填用户名）" : account.username)
                    .font(.body.weight(.medium))
                    .textSelection(.enabled)
                    .lineLimit(1)
                if !account.note.isEmpty {
                    Text(account.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if visible {
                    Text(password.isEmpty ? "（空）" : password)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 0)
            if state.passwordGloballyVisible {
                Text("统一显示中")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Button {
                    if visible {
                        state.concealAccount(account)
                    } else {
                        Task { await state.revealAccount(account) }
                    }
                } label: {
                    Image(systemName: visible ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
                .help(visible ? "隐藏密码" : "显示密码（需要认证）")
            }
            Button {
                Task { await state.copyAccountPassword(account) }
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("复制密码")
            Menu {
                Button("编辑") {
                    subAccountTarget = SubAccountTarget(itemId: account.itemId, itemTitle: itemTitle, original: account)
                }
                Button("复制用户名") { state.copyAccountUsername(account) }
                Divider()
                Button("删除", role: .destructive) {
                    pendingDeleteAccount = account
                    showDeleteAccountConfirm = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("更多操作")
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private func notesSection(for item: CredentialItem) -> some View {
        Group {
            if item.notesEnc != nil {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("备注").font(.headline)
                        Spacer()
                        if notesRevealedFor == item.id {
                            Button("隐藏") { notesRevealedFor = nil }
                                .controlSize(.small)
                        } else {
                            Button("显示") {
                                Task {
                                    if await state.requireAuth() {
                                        withAnimation { notesRevealedFor = item.id }
                                    }
                                }
                            }
                            .controlSize(.small)
                            .help("显示备注（需要认证）")
                        }
                    }
                    .padding(.bottom, 4)
                    if notesRevealedFor == item.id {
                        Text(state.decryptedFields(item).notes)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    } else {
                        Text("备注已加密存储，点击「显示」并认证后查看")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func metaSection(for item: CredentialItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("时间")
                .font(.headline)
                .padding(.bottom, 4)
            fieldRow("创建于") {
                Text(item.createdAt, format: .dateTime.year().month().day().hour().minute())
                    .foregroundStyle(.secondary)
            }
            Divider()
            fieldRow("更新于") {
                Text(item.updatedAt, format: .dateTime.year().month().day().hour().minute())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    private func trashActions(for item: CredentialItem) -> some View {
        HStack(spacing: 12) {
            Button {
                state.restore(item)
            } label: {
                Label("恢复", systemImage: "arrow.uturn.backward")
            }
            Button(role: .destructive) {
                confirmDeleteForever = true
            } label: {
                Label("彻底删除", systemImage: "trash")
            }
        }
        .padding(.top, 16)
        .confirmationDialog(
            "彻底删除「\(item.title)」？",
            isPresented: $confirmDeleteForever,
            titleVisibility: .visible
        ) {
            Button("彻底删除（不可恢复）", role: .destructive) {
                state.deleteForever(item)
            }
        } message: {
            Text("该操作不可撤销，密码数据将被永久删除。")
        }
    }

    // MARK: - 基础行

    private func fieldRow<Content: View>(_ label: String, @ViewBuilder value: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)
            value()
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
    }

    private func valueWithCopy(_ text: String, hideCopy: Bool = false, copyAction: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Text(text.isEmpty ? "—" : text)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
            if !text.isEmpty, !hideCopy {
                Button(action: copyAction) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("复制")
            }
            Spacer(minLength: 0)
        }
    }
}
