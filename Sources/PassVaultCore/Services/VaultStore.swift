import Foundation
import GRDB

/// SQLite 数据存取层。个人规模（数百条）单用户使用。
public final class VaultStore {
    private let dbQueue: DatabaseQueue

    /// path 为 nil 时使用内存库（单测用）
    public init(path: String?) throws {
        let configuration = Configuration()
        if let path {
            dbQueue = try DatabaseQueue(path: path, configuration: configuration)
        } else {
            dbQueue = try DatabaseQueue(configuration: configuration)
        }
        try Self.migrator.migrate(dbQueue)
    }

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "category") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull().unique()
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(table: "credential") { t in
                t.primaryKey("id", .text)
                t.column("category", .text).notNull()
                t.column("customCategoryId", .text).references("category", onDelete: .setNull)
                t.column("title", .text).notNull()
                t.column("username", .text).notNull().defaults(to: "")
                t.column("url", .text)
                t.column("host", .text)
                t.column("port", .integer)
                t.column("dbType", .text)
                t.column("passwordEnc", .blob).notNull()
                t.column("notesEnc", .blob)
                t.column("tags", .text).notNull().defaults(to: "")
                t.column("favorite", .boolean).notNull().defaults(to: false)
                t.column("deletedAt", .datetime)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
        }
        migrator.registerMigration("v2") { db in
            // 一个条目（标题）下的多组附加账号
            try db.create(table: "account") { t in
                t.primaryKey("id", .text)
                t.column("itemId", .text).notNull().references("credential", onDelete: .cascade)
                t.column("username", .text).notNull().defaults(to: "")
                t.column("passwordEnc", .blob).notNull()
                t.column("note", .text).notNull().defaults(to: "")
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
        }
        migrator.registerMigration("v3") { db in
            // 数据库条目的「数据库名」字段
            try db.alter(table: "credential") { t in
                t.add(column: "dbName", .text)
            }
        }
        return migrator
    }

    // MARK: - 条目

    public func fetchActiveItems() throws -> [CredentialItem] {
        try dbQueue.read { db in
            try CredentialItem.filter(sql: "deletedAt IS NULL").fetchAll(db)
        }
    }

    public func fetchDeletedItems() throws -> [CredentialItem] {
        try dbQueue.read { db in
            try CredentialItem.filter(sql: "deletedAt IS NOT NULL").fetchAll(db)
        }
    }

    @discardableResult
    public func insert(_ item: CredentialItem) throws -> CredentialItem {
        var copy = item
        try dbQueue.write { db in try copy.insert(db) }
        return copy
    }

    @discardableResult
    public func update(_ item: CredentialItem) throws -> CredentialItem {
        try dbQueue.write { db in try item.update(db) }
        return item
    }

    public func moveToTrash(id: UUID) throws {
        try dbQueue.write { db in
            try db.execute(sql: "UPDATE credential SET deletedAt = ? WHERE id = ?", arguments: [Date(), id])
        }
    }

    public func restore(id: UUID) throws {
        try dbQueue.write { db in
            try db.execute(sql: "UPDATE credential SET deletedAt = NULL WHERE id = ?", arguments: [id])
        }
    }

    public func setFavorite(id: UUID, favorite: Bool) throws {
        try dbQueue.write { db in
            try db.execute(sql: "UPDATE credential SET favorite = ? WHERE id = ?", arguments: [favorite, id])
        }
    }

    public func deleteForever(id: UUID) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM account WHERE itemId = ?", arguments: [id])
            try db.execute(sql: "DELETE FROM credential WHERE id = ?", arguments: [id])
        }
    }

    public func emptyTrash() throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM account WHERE itemId IN (SELECT id FROM credential WHERE deletedAt IS NOT NULL)")
            try db.execute(sql: "DELETE FROM credential WHERE deletedAt IS NOT NULL")
        }
    }

    // MARK: - 附加账号（一个条目多组账号）

    public func fetchAccounts(itemId: UUID) throws -> [SubAccount] {
        try dbQueue.read { db in
            try SubAccount.filter(Column("itemId") == itemId).order(Column("createdAt")).fetchAll(db)
        }
    }

    public func fetchAllAccounts() throws -> [SubAccount] {
        try dbQueue.read { db in
            try SubAccount.fetchAll(db)
        }
    }

    @discardableResult
    public func insert(_ account: SubAccount) throws -> SubAccount {
        var copy = account
        try dbQueue.write { db in try copy.insert(db) }
        return copy
    }

    @discardableResult
    public func update(_ account: SubAccount) throws -> SubAccount {
        try dbQueue.write { db in try account.update(db) }
        return account
    }

    public func deleteAccount(id: UUID) throws {
        try dbQueue.write { db in
            try SubAccount.filter(Column("id") == id).deleteAll(db)
        }
    }

    /// 合并条目时，把某条目下的全部附加账号转移到目标条目
    public func reparentAccounts(from itemId: UUID, to targetId: UUID) throws {
        try dbQueue.write { db in
            try db.execute(sql: "UPDATE account SET itemId = ? WHERE itemId = ?", arguments: [targetId, itemId])
        }
    }

    // MARK: - 自定义分类

    public func fetchCategories() throws -> [CustomCategory] {
        try dbQueue.read { db in
            try CustomCategory.order(Column("createdAt")).fetchAll(db)
        }
    }

    /// 重名时返回 nil
    @discardableResult
    public func addCategory(name: String) throws -> CustomCategory? {
        try dbQueue.write { db in
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            if try CustomCategory.filter(Column("name") == trimmed).fetchOne(db) != nil { return nil }
            var category = CustomCategory(id: UUID(), name: trimmed, createdAt: Date())
            try category.insert(db)
            return category
        }
    }

    public func renameCategory(id: UUID, to name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        try dbQueue.write { db in
            try db.execute(sql: "UPDATE category SET name = ? WHERE id = ?", arguments: [trimmed, id])
        }
    }

    public func deleteCategory(id: UUID) throws {
        try dbQueue.write { db in
            try CustomCategory.filter(Column("id") == id).deleteAll(db)
            try db.execute(sql: "UPDATE credential SET customCategoryId = NULL WHERE customCategoryId = ?", arguments: [id])
        }
    }
}
