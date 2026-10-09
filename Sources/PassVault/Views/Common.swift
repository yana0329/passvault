import AppKit
import PassVaultCore
import SwiftUI

// MARK: - 通用类型

/// 编辑弹窗上下文（original 为 nil 表示新建）
struct EditTarget: Identifiable {
    let id = UUID()
    let original: CredentialItem?
}

struct GeneratorContext: Identifiable {
    let id = UUID()
    let initialPassword: String
}

// MARK: - 分类颜色与徽标

extension ItemCategory {
    var color: Color {
        switch self {
        case .browser: return .blue
        case .server: return .orange
        case .database: return .green
        case .other: return .gray
        }
    }
}

struct CategoryBadge: View {
    let category: ItemCategory
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: category.symbolName)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(category.color.gradient, in: RoundedRectangle(cornerRadius: size * 0.28))
    }
}

// MARK: - 文件对话框

enum FileDialog {
    static func chooseFile(title: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseSaveLocation(title: String, defaultName: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = title
        panel.nameFieldStringValue = defaultName
        return panel.runModal() == .OK ? panel.url : nil
    }
}

/// 打开网址（缺省补 https://）
func openInBrowser(_ urlString: String) {
    var trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty, !trimmed.lowercased().hasPrefix("http://"), !trimmed.lowercased().hasPrefix("https://") {
        trimmed = "https://" + trimmed
    }
    if let url = URL(string: trimmed) {
        NSWorkspace.shared.open(url)
    }
}
