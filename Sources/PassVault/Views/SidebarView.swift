import PassVaultCore
import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var state
    @State private var renameTarget: CustomCategory?
    @State private var deleteCandidate: CustomCategory?
    @State private var showDeleteConfirm = false

    var body: some View {
        @Bindable var state = state
        List(selection: $state.selection) {
            Section {
                sidebarRow(.all, symbol: "tray.2", label: "全部条目", color: .secondary)
                sidebarRow(.favorites, symbol: "star", label: "收藏", color: .yellow)
            }
            Section("分类") {
                sidebarRow(.builtIn(.browser), symbol: "globe", label: "浏览器", color: .blue)
                sidebarRow(.builtIn(.server), symbol: "server.rack", label: "服务器", color: .orange)
                sidebarRow(.builtIn(.database), symbol: "cylinder", label: "数据库", color: .green)
                sidebarRow(.builtIn(.other), symbol: "archivebox", label: "其他", color: .gray)
                ForEach(state.categories) { category in
                    sidebarRow(.custom(category.id), symbol: "folder", label: category.name, color: .purple)
                        .contextMenu {
                            Button("重命名…") { renameTarget = category }
                            Button("删除…", role: .destructive) {
                                deleteCandidate = category
                                showDeleteConfirm = true
                            }
                        }
                }
            }
            if !state.allTags.isEmpty {
                Section("标签") {
                    ForEach(state.allTags, id: \.self) { tag in
                        sidebarRow(.tag(tag), symbol: "tag", label: tag, color: .secondary)
                    }
                }
            }
            Section {
                sidebarRow(.trash, symbol: "trash", label: "回收站", color: .secondary)
            }
        }
        .listStyle(.sidebar)
        .onChange(of: state.selection) { _, _ in state.refresh() }
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

    private func sidebarRow(_ target: AppState.SidebarSelection, symbol: String, label: String, color: Color) -> some View {
        Label {
            HStack {
                Text(label)
                Spacer()
                Text("\(state.count(for: target))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(color)
        }
        .tag(target)
    }
}
