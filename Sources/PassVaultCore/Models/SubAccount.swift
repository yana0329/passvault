import Foundation
import GRDB

/// 条目下的附加账号：一个标题（站点/服务器）可挂多组账号密码
public struct SubAccount: Codable, Identifiable, Hashable, FetchableRecord, MutablePersistableRecord {
    public var id: UUID
    public var itemId: UUID
    public var username: String
    public var passwordEnc: Data
    public var note: String
    public var createdAt: Date
    public var updatedAt: Date

    public static let databaseTableName = "account"

    public init(id: UUID, itemId: UUID, username: String, passwordEnc: Data, note: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.itemId = itemId
        self.username = username
        self.passwordEnc = passwordEnc
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
