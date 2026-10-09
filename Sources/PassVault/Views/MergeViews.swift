import PassVaultCore
import SwiftUI

/// 详情页 / 列表右键发起合并的上下文
struct MergeRequest: Identifiable {
    let id = UUID()
    let items: [CredentialItem]
}

/// 多选合并：可选保留条目，其余并入并移入回收站
struct MergeSheet: View {
    let request: MergeRequest

    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var targetId: UUID?

    private var items: [CredentialItem] { request.items }
    private var others: [CredentialItem] { items.filter { $0.id != targetId } }

    var body: some View {
        VStack(spacing: 14) {
            Text("合并条目")
                .font(.headline)
            Text("将 \(items.count) 个条目合并为一个，各条目的账号全部归入保留条目。")
                .font(.callout)
                .foregroundStyle(.secondary)

            Form {
                Picker("保留条目", selection: $targetId) {
                    ForEach(items) { item in
                        Text(rowLabel(item)).tag(UUID?.some(item.id))
                    }
                }
                Section("并入以下条目（合并后移入回收站）") {
                    ForEach(others) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title.isEmpty ? "（未命名）" : item.title)
                            Text(item.subtitle.isEmpty ? "无用户名" : item.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    Text("""
                    · 并入条目的主账号将变为保留条目的附加账号，其附加账号一并转移
                    · 并入条目本身移入回收站（可恢复），确认无误后可在回收站彻底删除
                    · 备注、网址 / 主机等字段以保留条目为准，不随合并迁移
                    """)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("取消", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("合并") { merge() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(targetId == nil || others.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480, height: 460)
        .onAppear {
            if targetId == nil {
                targetId = items.min(by: { $0.createdAt < $1.createdAt })?.id
            }
        }
    }

    private func rowLabel(_ item: CredentialItem) -> String {
        let extra = item.username.isEmpty ? "" : " · \(item.username)"
        return "\(item.title.isEmpty ? "（未命名）" : item.title)\(extra)"
    }

    private func merge() {
        guard let targetId, let target = items.first(where: { $0.id == targetId }) else {
            dismiss()
            return
        }
        state.mergeItems(target: target, others: others)
        dismiss()
    }
}

/// 一键扫描同标题条目并按组合并（每组保留最早创建的条目）
struct DuplicateScanSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var groups: [[CredentialItem]] = []
    @State private var checked: Set<Int> = []
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 14) {
            Text("合并同标题条目")
                .font(.headline)
            if groups.isEmpty {
                Text("没有发现同标题的重复条目")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                Text("发现 \(groups.count) 组同标题条目，每组将保留最早创建的一条，其余账号并入其中并移入回收站。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                List {
                    ForEach(groups.indices, id: \.self) { index in
                        Toggle(isOn: indexBinding(index)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(groups[index][0].title)（\(groups[index].count) 条）")
                                    .fontWeight(.medium)
                                Text(previewLabel(groups[index]))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
                .frame(minHeight: 220)
            }
            HStack {
                Spacer()
                Button("取消", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("合并所选组") { mergeChecked() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(groups.isEmpty || checked.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 500, height: 380)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            groups = state.duplicateTitleGroups()
            checked = Set(groups.indices)
        }
    }

    private func previewLabel(_ group: [CredentialItem]) -> String {
        group.map { $0.username.isEmpty ? "（无用户名）" : $0.username }.joined(separator: "、")
    }

    private func indexBinding(_ index: Int) -> Binding<Bool> {
        Binding(
            get: { checked.contains(index) },
            set: { if $0 { checked.insert(index) } else { checked.remove(index) } }
        )
    }

    private func mergeChecked() {
        let selected = checked.sorted().compactMap { index -> [[CredentialItem]]? in
            guard index < groups.count else { return nil }
            return [groups[index]]
        }
        state.mergeGroups(selected.flatMap { $0 })
        dismiss()
    }
}
