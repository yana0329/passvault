import AppKit

/// 剪贴板工具。敏感内容复制后延时自动清除（期间用户复制了新内容则不动），
/// 并写入 Concealed 标记，配合 Maccy 等剪贴板历史工具避免密码被记录。
public enum ClipboardService {
    public static func copyPlain(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    public static func copySensitive(_ text: String, clearAfter seconds: TimeInterval) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        pb.setString("org.nspasteboard.ConcealedType", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        guard seconds > 0, !text.isEmpty else { return }
        let snapshot = pb.changeCount
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            guard NSPasteboard.general.changeCount == snapshot else { return }
            NSPasteboard.general.clearContents()
        }
    }
}
