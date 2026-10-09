import CryptoKit
import Foundation
import Security

public struct BackupAccount: Codable {
    public var username: String
    public var password: String
    public var note: String

    public init(username: String, password: String, note: String) {
        self.username = username
        self.password = password
        self.note = note
    }
}

public struct BackupItem: Codable {
    public var category: ItemCategory
    public var customCategoryName: String?
    public var title: String
    public var username: String
    public var url: String?
    public var host: String?
    public var port: Int?
    public var dbType: String?
    public var dbName: String?
    public var password: String
    public var notes: String?
    public var tags: String
    public var favorite: Bool
    public var createdAt: Date
    public var updatedAt: Date
    /// 条目下的附加账号（v1 备份文件无此字段，解码为 nil）
    public var accounts: [BackupAccount]?

    public init(
        category: ItemCategory,
        customCategoryName: String?,
        title: String,
        username: String,
        url: String?,
        host: String?,
        port: Int?,
        dbType: String?,
        dbName: String? = nil,
        password: String,
        notes: String?,
        tags: String,
        favorite: Bool,
        createdAt: Date,
        updatedAt: Date,
        accounts: [BackupAccount]? = nil
    ) {
        self.category = category
        self.customCategoryName = customCategoryName
        self.title = title
        self.username = username
        self.url = url
        self.host = host
        self.port = port
        self.dbType = dbType
        self.dbName = dbName
        self.password = password
        self.notes = notes
        self.tags = tags
        self.favorite = favorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.accounts = accounts
    }
}

public struct BackupPayload: Codable {
    public var items: [BackupItem]
    public var categories: [CustomCategory]
}

public struct BackupContainer: Codable {
    public var magic = "PASSVAULT_BACKUP"
    public var version = 1
    public var kdfSalt: Data
    public var kdfIterations: Int
    public var payload: Data

    enum CodingKeys: String, CodingKey {
        case magic, version
        case kdfSalt = "kdf_salt"
        case kdfIterations = "kdf_iterations"
        case payload
    }
}

public enum BackupError: LocalizedError, Equatable {
    case badFormat
    case wrongPassword

    public var errorDescription: String? {
        switch self {
        case .badFormat: return "不是有效的 PassVault 备份文件"
        case .wrongPassword: return "备份密码错误或文件已损坏"
        }
    }
}

/// 加密备份（.pvbak）：主密钥绑定本机钥匙串，换机恢复只能通过该文件。
/// 文件格式：JSON { magic, version, kdf_salt, kdf_iterations, payload(AES-GCM combined, b64) }
/// 密钥由用户输入的备份密码经 PBKDF2-SHA256 派生。
public enum BackupService {
    public static let kdfIterations = 210_000

    public static func export(items: [BackupItem], categories: [CustomCategory], password: String, to url: URL) throws {
        let payload = BackupPayload(items: items, categories: categories)
        let plaintext = try JSONEncoder().encode(payload)
        var saltBytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, saltBytes.count, &saltBytes)
        let salt = Data(saltBytes)
        let key = CryptoService.deriveKey(password: password, salt: salt, iterations: kdfIterations)
        let box = try AES.GCM.seal(plaintext, using: SymmetricKey(data: key))
        guard let combined = box.combined else { throw BackupError.badFormat }
        let container = BackupContainer(kdfSalt: salt, kdfIterations: kdfIterations, payload: combined)
        let data = try JSONEncoder().encode(container)
        try data.write(to: url, options: [.atomic])
    }

    public static func importBackup(from url: URL, password: String) throws -> BackupPayload {
        let container: BackupContainer
        do {
            container = try JSONDecoder().decode(BackupContainer.self, from: try Data(contentsOf: url))
        } catch {
            throw BackupError.badFormat
        }
        guard container.magic == "PASSVAULT_BACKUP" else { throw BackupError.badFormat }
        let key = CryptoService.deriveKey(password: password, salt: container.kdfSalt, iterations: container.kdfIterations)
        do {
            let box = try AES.GCM.SealedBox(combined: container.payload)
            let plaintext = try AES.GCM.open(box, using: SymmetricKey(data: key))
            return try JSONDecoder().decode(BackupPayload.self, from: plaintext)
        } catch {
            throw BackupError.wrongPassword
        }
    }
}
