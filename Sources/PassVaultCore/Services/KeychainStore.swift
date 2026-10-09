import CryptoKit
import Foundation
import Security

/// 主密钥的钥匙串存取。密钥只在本机（ThisDeviceOnly），不随 iCloud 或备份同步。
public enum KeychainStore {
    public static let service = "com.hc.passvault"
    public static let masterKeyAccount = "master-key"

    public enum KeychainError: LocalizedError {
        case unhandled(OSStatus)

        public var errorDescription: String? {
            switch self {
            case .unhandled(let status): return "钥匙串操作失败（错误码 \(status)）"
            }
        }
    }

    public static func loadOrCreateMasterKey() throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: masterKeyAccount,
            kSecReturnData as String: true
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return SymmetricKey(data: data)
        }
        guard status == errSecItemNotFound else { throw KeychainError.unhandled(status) }

        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw KeychainError.unhandled(errSecParam)
        }
        let keyData = Data(bytes)
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: masterKeyAccount,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: keyData
        ]
        let addStatus = SecItemAdd(attributes as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError.unhandled(addStatus) }
        return SymmetricKey(data: keyData)
    }
}
