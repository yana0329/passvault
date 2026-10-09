import Foundation
import PassVaultCore

func vaultStoreTests() throws {
    try insertFetchUpdate()
    try trashFlow()
    try emptyTrashFlow()
    try customCategoryLifecycle()
    try renameCategoryTest()
    try subAccountCRUD()
    try deleteForeverCascadesAccounts()
}

private func makeStore() throws -> VaultStore {
    try VaultStore(path: nil)
}

private func insertFetchUpdate() throws {
    let store = try makeStore()
    var item = CredentialItem.empty(category: .server)
    item.title = "生产服务器"
    item.username = "root"
    item.host = "10.0.0.1"
    item.port = 22
    try store.insert(item)

    var fetched = try store.fetchActiveItems()
    check(fetched.count == 1, "应查询到 1 条，实际 \(fetched.count)")
    check(fetched[0].title == "生产服务器" && fetched[0].category == .server, "插入内容应一致")
    check(fetched[0].port == 22, "端口应一致")

    item.title = "改名"
    item.favorite = true
    item.dbName = "orders_db"
    try store.update(item)
    fetched = try store.fetchActiveItems()
    check(fetched[0].title == "改名" && fetched[0].favorite, "更新应生效")
    check(fetched[0].dbName == "orders_db", "数据库名更新应生效")
}

private func trashFlow() throws {
    let store = try makeStore()
    let item = CredentialItem.empty(category: .browser)
    try store.insert(item)

    try store.moveToTrash(id: item.id)
    check(try store.fetchActiveItems().isEmpty, "移入回收站后活动列表应为空")
    check(try store.fetchDeletedItems().count == 1, "回收站应有一条")

    try store.restore(id: item.id)
    check(try store.fetchActiveItems().count == 1, "恢复后活动列表应有一条")
    check(try store.fetchDeletedItems().isEmpty, "恢复后回收站应为空")

    try store.moveToTrash(id: item.id)
    try store.deleteForever(id: item.id)
    check(try store.fetchActiveItems().isEmpty, "彻底删除后活动列表应为空")
    check(try store.fetchDeletedItems().isEmpty, "彻底删除后回收站应为空")
}

private func emptyTrashFlow() throws {
    let store = try makeStore()
    for i in 0..<3 {
        var item = CredentialItem.empty(category: .other)
        item.title = "item-\(i)"
        try store.insert(item)
        try store.moveToTrash(id: item.id)
    }
    var active = CredentialItem.empty(category: .other)
    active.title = "keep"
    try store.insert(active)

    try store.emptyTrash()
    let items = try store.fetchActiveItems()
    check(items.count == 1 && items[0].title == "keep", "清空回收站后只应剩未删除条目")
    check(try store.fetchDeletedItems().isEmpty, "回收站应为空")
}

private func customCategoryLifecycle() throws {
    let store = try makeStore()
    let category = try store.addCategory(name: "云服务")
    check(category != nil, "添加分类应成功")
    check(try store.addCategory(name: "云服务") == nil, "重名分类应添加失败")
    check(try store.addCategory(name: "   ") == nil, "空白名称应添加失败")

    var item = CredentialItem.empty(category: .other)
    item.customCategoryId = category?.id
    try store.insert(item)
    check(try store.fetchCategories().count == 1, "分类数量应为 1")

    try store.deleteCategory(id: category!.id)
    check(try store.fetchCategories().isEmpty, "删除后分类应为空")
    let items = try store.fetchActiveItems()
    check(items[0].customCategoryId == nil, "删除分类后条目的分类引用应置空")
}

private func renameCategoryTest() throws {
    let store = try makeStore()
    let category = try store.addCategory(name: "旧名")
    try store.renameCategory(id: category!.id, to: "新名")
    check(try store.fetchCategories().first?.name == "新名", "重命名应生效")
}

private func subAccountCRUD() throws {
    let store = try makeStore()
    let item = CredentialItem.empty(category: .browser)
    try store.insert(item)

    check(try store.fetchAccounts(itemId: item.id).isEmpty, "初始应无附加账号")

    let account1 = SubAccount(id: UUID(), itemId: item.id, username: "work@x.com", passwordEnc: Data([1, 2, 3]), note: "工作", createdAt: Date(), updatedAt: Date())
    try store.insert(account1)
    let account2 = SubAccount(id: UUID(), itemId: item.id, username: "me@y.com", passwordEnc: Data([4, 5]), note: "", createdAt: Date().addingTimeInterval(1), updatedAt: Date())
    try store.insert(account2)

    var accounts = try store.fetchAccounts(itemId: item.id)
    check(accounts.count == 2, "应有 2 个附加账号，实际 \(accounts.count)")
    check(accounts[0].username == "work@x.com", "按创建时间排序")
    check(try store.fetchAllAccounts().count == 2, "fetchAllAccounts 应返回全部")

    var updated = account1
    updated.username = "new@x.com"
    try store.update(updated)
    accounts = try store.fetchAccounts(itemId: item.id)
    check(accounts[0].username == "new@x.com", "更新应生效")

    try store.deleteAccount(id: account2.id)
    check(try store.fetchAccounts(itemId: item.id).count == 1, "删除后应剩 1 个")
}

private func deleteForeverCascadesAccounts() throws {
    let store = try makeStore()
    let item = CredentialItem.empty(category: .server)
    try store.insert(item)
    let account = SubAccount(id: UUID(), itemId: item.id, username: "root2", passwordEnc: Data([9]), note: "", createdAt: Date(), updatedAt: Date())
    try store.insert(account)

    // 移到回收站：附加账号保留（恢复后仍在）
    try store.moveToTrash(id: item.id)
    check(try store.fetchAllAccounts().count == 1, "回收站中的条目应保留附加账号")
    try store.restore(id: item.id)
    check(try store.fetchAccounts(itemId: item.id).count == 1, "恢复后附加账号仍在")

    // 彻底删除：附加账号一并清除
    try store.deleteForever(id: item.id)
    check(try store.fetchAllAccounts().isEmpty, "彻底删除条目后附加账号应级联清除")

    // 清空回收站：同样级联
    let item2 = CredentialItem.empty(category: .other)
    try store.insert(item2)
    try store.insert(SubAccount(id: UUID(), itemId: item2.id, username: "a", passwordEnc: Data(), note: "", createdAt: Date(), updatedAt: Date()))
    try store.moveToTrash(id: item2.id)
    try store.emptyTrash()
    check(try store.fetchAllAccounts().isEmpty, "清空回收站后附加账号应级联清除")
}
