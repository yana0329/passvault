import Foundation
import GRDB

/// 一条账号密码记录。密码与备注以 AES-GCM 密文（passwordEnc / notesEnc）落库，
/// 其余元数据明文存储以支持搜索。
public struct CredentialItem: Codable, Identifiable, Hashable, FetchableRecord, MutablePersistableRecord {
    public var id: UUID
    public var category: ItemCategory
    public var customCategoryId: UUID?
    public var title: String
    public var username: String
    public var url: String?
    public var host: String?
    public var port: Int?
    public var dbType: String?
    /// 数据库名（database 分类专用，如 orders_db）
    public var dbName: String?
    public var passwordEnc: Data
    public var notesEnc: Data?
    public var tags: String
    public var favorite: Bool
    public var deletedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date

    public static let databaseTableName = "credential"

    public var tagList: [String] {
        tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// 列表副标题：用户名 · 主机:端口 · 库名 · 网址
    public var subtitle: String {
        var parts: [String] = []
        if !username.isEmpty { parts.append(username) }
        if let host, !host.isEmpty {
            parts.append(port.map { "\(host):\($0)" } ?? host)
        }
        if let dbName, !dbName.isEmpty {
            parts.append(dbName)
        }
        if let url, !url.isEmpty { parts.append(url) }
        return parts.joined(separator: "  ·  ")
    }

    public init(
        id: UUID,
        category: ItemCategory,
        customCategoryId: UUID?,
        title: String,
        username: String,
        url: String?,
        host: String?,
        port: Int?,
        dbType: String?,
        dbName: String? = nil,
        passwordEnc: Data,
        notesEnc: Data?,
        tags: String,
        favorite: Bool,
        deletedAt: Date?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.category = category
        self.customCategoryId = customCategoryId
        self.title = title
        self.username = username
        self.url = url
        self.host = host
        self.port = port
        self.dbType = dbType
        self.dbName = dbName
        self.passwordEnc = passwordEnc
        self.notesEnc = notesEnc
        self.tags = tags
        self.favorite = favorite
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func empty(category: ItemCategory) -> CredentialItem {
        CredentialItem(
            id: UUID(),
            category: category,
            customCategoryId: nil,
            title: "",
            username: "",
            url: nil,
            host: nil,
            port: nil,
            dbType: nil,
            dbName: nil,
            passwordEnc: Data(),
            notesEnc: nil,
            tags: "",
            favorite: false,
            deletedAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
