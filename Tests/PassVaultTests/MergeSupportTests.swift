import CryptoKit
import Foundation
import PassVaultCore

func mergeSupportTests() {
    // 同组识别：同分类同标题（忽略大小写）合并为一组；不同分类不合并；单条不成组
    var old = CredentialItem.empty(category: .browser)
    old.title = "GitHub"
    old.username = "old"
    old.createdAt = Date(timeIntervalSince1970: 100)

    var new = CredentialItem.empty(category: .browser)
    new.title = "  github "
    new.username = "new"
    new.createdAt = Date(timeIntervalSince1970: 200)

    var server = CredentialItem.empty(category: .server)
    server.title = "GitHub"
    server.username = "srv"
    server.createdAt = Date(timeIntervalSince1970: 50)

    var other = CredentialItem.empty(category: .browser)
    other.title = "GitLab"
    other.username = "other"

    let groups = MergeSupport.duplicateGroups(of: [new, old, server, other])
    check(groups.count == 1, "应只发现 1 组同标题条目，实际 \(groups.count)")
    check(groups[0].count == 2, "组内应为 2 条")
    check(groups[0][0].id == old.id, "组内按创建时间升序，最早的在前")

    let multi = MergeSupport.duplicateGroups(of: [old, new, server])
    check(multi.count == 1, "不同分类的同名条目不应合并到同组")

    // 主账号转附加账号
    let crypto = CryptoService(key: SymmetricKey(size: .bits256))
    old.passwordEnc = (try! crypto.encryptString("old-pass", aad: "password:\(old.id.uuidString)"))
    let targetId = UUID()
    let account = try! MergeSupport.makeSubAccount(from: old, targetId: targetId, crypto: crypto)
    check(account != nil, "有用户名/密码时应生成附加账号")
    check(account?.itemId == targetId, "附加账号应指向目标条目")
    check(account?.username == "old", "用户名应原样保留")
    check(try! crypto.decryptString(account!.passwordEnc, aad: "account-password:\(account!.id.uuidString)") == "old-pass", "密码应重新加密且可解密")

    // 用户名密码都为空 → nil
    var empty = CredentialItem.empty(category: .other)
    empty.title = "空条目"
    let none = try? MergeSupport.makeSubAccount(from: empty, targetId: targetId, crypto: crypto)
    check(none == nil, "无用户名无密码的条目不应生成附加账号")
}
