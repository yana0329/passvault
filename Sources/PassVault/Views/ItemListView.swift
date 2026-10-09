import PassVaultCore
import SwiftUI

/// 列表分组：浏览器按网址域名、服务器/数据库按主机 IP 归组
struct ItemGroup: Identifiable {
    let id: String
    let title: String
    let items: [CredentialItem]
}

struct ItemListView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索标题、用户名、主机、标签…", text: $state.searchText)
                    .textFieldStyle(.plain)
                if !state.searchText.isEmpty {
                    Button {
                        state.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            Divider()
            if state.items.isEmpty {
                emptyView
            } else {
                List(selection: $state.selectedItemIds) {
                    ForEach(groups) { group in
                        if group.title.isEmpty {
                            sectionRows(group)
                        } else {
                            Section {
                                sectionRows(group)
                            } header: {
                                Text("\(group.title) · \(group.items.count)")
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .onChange(of: state.searchText) { _, _ in state.refresh() }
        .sheet(item: $mergeRequest) { request in
            MergeSheet(request: request)
        }
    }

    @State private var mergeRequest: MergeRequest?

    // MARK: - 分组

    private var isGroupedView: Bool {
        switch state.selection {
        case .builtIn(.browser), .builtIn(.server), .builtIn(.database):
            return true
        default:
            return false
        }
    }

    private var groups: [ItemGroup] {
        guard isGroupedView else {
            return [ItemGroup(id: "", title: "", items: state.items)]
        }
        let emptyLabel: String
        switch state.selection {
        case .builtIn(.browser):
            emptyLabel = "未填写网址"
        default:
            emptyLabel = "未填写主机"
        }
        var buckets: [String: [CredentialItem]] = [:]
        var labels: [String] = []
        for item in state.items {
            let label = Self.groupLabel(for: item, selection: state.selection, emptyLabel: emptyLabel)
            if buckets[label] == nil {
                labels.append(label)
            }
            buckets[label, default: []].append(item)
        }
        let sorted = labels.sorted { a, b in
            let aEmpty = a == emptyLabel
            let bEmpty = b == emptyLabel
            if aEmpty != bEmpty { return bEmpty }
            return a.localizedStandardCompare(b) == .orderedAscending
        }
        return sorted.map { ItemGroup(id: $0, title: $0, items: buckets[$0]!) }
    }

    private static func groupLabel(for item: CredentialItem, selection: AppState.SidebarSelection, emptyLabel: String) -> String {
        let key: String
        switch selection {
        case .builtIn(.browser):
            key = URLNormalizer.host(from: item.url ?? "")
        default:
            key = (item.host ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return key.isEmpty ? emptyLabel : key
    }

    @ViewBuilder
    private func sectionRows(_ group: ItemGroup) -> some View {
        ForEach(group.items) { item in
            ItemRowView(item: item, isTrash: state.selection == .trash, accountCount: state.accountCount(for: item.id))
                .tag(item.id)
                .contextMenu { contextActions(for: item) }
        }
    }

    // MARK: - 空态与右键菜单

    @ViewBuilder
    private var emptyView: some View {
        switch state.selection {
        case .trash where state.items.isEmpty && !state.searchText.isEmpty:
            ContentUnavailableView.search(text: state.searchText)
        case .trash:
            ContentUnavailableView("回收站是空的", systemImage: "trash", description: Text("删除的条目会先进入回收站"))
        default:
            if !state.searchText.isEmpty {
                ContentUnavailableView.search(text: state.searchText)
            } else {
                ContentUnavailableView(
                    "还没有保存任何账号",
                    systemImage: "key.horizontal",
                    description: Text("点击工具栏的 ＋ 新建条目，保存浏览器、服务器、数据库等账号密码")
                )
            }
        }
    }

    @ViewBuilder
    private func contextActions(for item: CredentialItem) -> some View {
        if state.selection == .trash {
            Button("恢复") { state.restore(item) }
            Button("彻底删除…", role: .destructive) { state.deleteForever(item) }
        } else {
            if state.selectedItemIds.contains(item.id), state.multiSelectedCount > 1 {
                Button("合并所选条目…") {
                    mergeRequest = MergeRequest(items: state.multiSelectedItems)
                }
                Divider()
            }
            Button("编辑") { NotificationCenter.default.post(name: .pvEditItem, object: item) }
            Button("复制用户名") { state.copyUsername(item) }
            Button("复制密码") {
                Task { await state.copyPassword(item) }
            }
            Button(item.favorite ? "取消收藏" : "收藏") { state.toggleFavorite(item) }
            if !state.categories.isEmpty {
                Menu("移动到分组") {
                    ForEach(state.categories) { category in
                        Button(category.name) {
                            state.moveItem(item, toCustomCategory: category.id)
                        }
                    }
                    Divider()
                    Button("移出分组") {
                        state.moveItem(item, toCustomCategory: nil)
                    }
                    .disabled(item.customCategoryId == nil)
                }
            }
            Divider()
            Button("移到回收站", role: .destructive) { state.moveToTrash(item) }
        }
    }
}

struct ItemRowView: View {
    let item: CredentialItem
    let isTrash: Bool
    var accountCount: Int = 0

    /// 主账号未填用户名但有附加账号时，副标题显示账号数
    private var subtitleText: String? {
        if item.username.isEmpty, accountCount > 0 {
            return "\(accountCount) 个账号"
        }
        return item.subtitle.isEmpty ? nil : item.subtitle
    }

    var body: some View {
        HStack(spacing: 10) {
            CategoryBadge(category: item.category)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.title.isEmpty ? "（未命名）" : item.title)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if item.favorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                    if accountCount > 1 {
                        HStack(spacing: 2) {
                            Image(systemName: "person.2")
                            Text("\(accountCount)")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
                if let subtitleText {
                    Text(subtitleText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if isTrash {
                Image(systemName: "arrow.uturn.backward.circle")
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
