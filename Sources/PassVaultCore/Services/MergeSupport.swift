import Foundation

/// 条目合并支撑逻辑（纯函数，便于单测）
public enum MergeSupport {
    /// 找出同分类且标题相同（忽略大小写与首尾空格）的重复条目组
    /// 组内 ≥2 条，按创建时间升序（最早一条适合作为保留目标）；组之间按标题排序
    public static func duplicateGroups(of items: [CredentialItem]) -> [[CredentialItem]] {
        var buckets: [String: [CredentialItem]] = [:]
        var order: [String] = []
        for item in items {
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let key = "\(item.category.rawValue)|\(title)"
            if buckets[key] == nil {
                order.append(key)
            }
            buckets[key, default: []].append(item)
        }
        return order
            .compactMap { buckets[$0] }
            .filter { $0.count > 1 }
            .map { $0.sorted { $0.createdAt < $1.createdAt } }
            .sorted { ($0.first?.title ?? "") < ($1.first?.title ?? "") }
    }

    /// 把条目的主账号转换为保留条目的附加账号；用户名与密码都为空时返回 nil
    public static func makeSubAccount(from item: CredentialItem, targetId: UUID, crypto: CryptoService) throws -> SubAccount? {
        let username = item.username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty || !item.passwordEnc.isEmpty else { return nil }
        let password = item.passwordEnc.isEmpty
            ? ""
            : try crypto.decryptString(item.passwordEnc, aad: "password:\(item.id.uuidString)")
        var account = SubAccount(
            id: UUID(), itemId: targetId, username: username, passwordEnc: Data(),
            note: "", createdAt: item.createdAt, updatedAt: Date()
        )
        account.passwordEnc = try crypto.encryptString(password, aad: "account-password:\(account.id.uuidString)")
        return account
    }
}
