import Foundation
import PassVaultCore

func backupServiceTests() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("passvault-test-\(UUID().uuidString).pvbak")
    defer { try? FileManager.default.removeItem(at: url) }

    let categories = [CustomCategory(id: UUID(), name: "云服务", createdAt: Date())]
    let items = [
        BackupItem(
            category: .browser,
            customCategoryName: "云服务",
            title: "GitHub",
            username: "octocat",
            url: "https://github.com",
            host: nil,
            port: nil,
            dbType: nil,
            password: "p@ssw0rd 中文✓",
            notes: "备注内容",
            tags: "工作,开发",
            favorite: true,
            createdAt: Date(),
            updatedAt: Date(),
            accounts: [
                BackupAccount(username: "second", password: "pass2", note: "小号"),
                BackupAccount(username: "third", password: "pass3", note: "")
            ]
        ),
        BackupItem(
            category: .database,
            customCategoryName: nil,
            title: "生产库",
            username: "root",
            url: nil,
                host: "10.0.0.9",
                port: 3306,
                dbType: "MySQL",
                dbName: "orders_db",
                password: "",
            notes: nil,
            tags: "",
            favorite: false,
            createdAt: Date(),
            updatedAt: Date()
        )
    ]

    try BackupService.export(items: items, categories: categories, password: "备份密码123", to: url)
    let payload = try BackupService.importBackup(from: url, password: "备份密码123")

    check(payload.items.count == 2, "备份应含 2 条，实际 \(payload.items.count)")
    check(payload.items[0].password == "p@ssw0rd 中文✓", "密码应完整还原")
    check(payload.items[0].customCategoryName == "云服务", "自定义分类名应保留")
    check(payload.items[1].host == "10.0.0.9" && payload.items[1].port == 3306, "主机端口应还原")
    check(payload.items[1].dbName == "orders_db", "数据库名应还原")
    check(payload.categories.first?.name == "云服务", "分类应还原")
    check(payload.items[0].accounts?.count == 2, "附加账号应随备份保存")
    check(payload.items[0].accounts?[0].username == "second" && payload.items[0].accounts?[0].password == "pass2", "附加账号内容应完整还原")
    check(payload.items[1].accounts == nil, "无附加账号时为 nil")

    expectThrows(BackupError.wrongPassword, {
        try BackupService.importBackup(from: url, password: "wrong-password")
    }, message: "错误备份密码应报 wrongPassword")

    let badFile = FileManager.default.temporaryDirectory
        .appendingPathComponent("not-a-backup-\(UUID().uuidString).pvbak")
    try Data("hello".utf8).write(to: badFile)
    defer { try? FileManager.default.removeItem(at: badFile) }
    expectThrows(BackupError.badFormat, {
        try BackupService.importBackup(from: badFile, password: "x")
    }, message: "非备份文件应报 badFormat")
}
