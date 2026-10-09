import Foundation
import GRDB

/// 内置条目分类
public enum ItemCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case browser
    case server
    case database
    case other

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .browser: return "浏览器"
        case .server: return "服务器"
        case .database: return "数据库"
        case .other: return "其他"
        }
    }

    public var symbolName: String {
        switch self {
        case .browser: return "globe"
        case .server: return "server.rack"
        case .database: return "cylinder"
        case .other: return "archivebox"
        }
    }
}

/// 数据库类型选项（database 分类使用）
public enum DatabaseKind {
    public static let all = ["MySQL", "PostgreSQL", "Redis", "MongoDB", "SQL Server", "Oracle", "SQLite", "Elasticsearch", "其他"]
}

/// 用户自定义分类
public struct CustomCategory: Codable, Identifiable, Hashable, FetchableRecord, MutablePersistableRecord {
    public var id: UUID
    public var name: String
    public var createdAt: Date

    public static let databaseTableName = "category"

    public init(id: UUID, name: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}
