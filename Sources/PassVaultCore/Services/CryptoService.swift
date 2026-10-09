import CryptoKit
import CommonCrypto
import Foundation

/// 字段级加密服务：AES-256-GCM，AAD 绑定字段名与记录 ID，防止密文在记录间移植。
public struct CryptoService {
    public let key: SymmetricKey

    public enum CryptoError: Error { case sealFailed }

    public init(key: SymmetricKey) { self.key = key }

    public func encrypt(_ plaintext: Data, aad: String) throws -> Data {
        let box = try AES.GCM.seal(plaintext, using: key, authenticating: Data(aad.utf8))
        guard let combined = box.combined else { throw CryptoError.sealFailed }
        return combined
    }

    public func decrypt(_ combined: Data, aad: String) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(box, using: key, authenticating: Data(aad.utf8))
    }

    public func encryptString(_ string: String, aad: String) throws -> Data {
        try encrypt(Data(string.utf8), aad: aad)
    }

    public func decryptString(_ data: Data, aad: String) throws -> String {
        guard let string = String(data: try decrypt(data, aad: aad), encoding: .utf8) else {
            throw CryptoError.sealFailed
        }
        return string
    }

    public static func randomKey() -> SymmetricKey { SymmetricKey(size: .bits256) }

    /// PBKDF2-HMAC-SHA256 密钥派生（备份文件加密用）
    public static func deriveKey(password: String, salt: Data, iterations: Int = 210_000, length: Int = 32) -> Data {
        var derived = Data(repeating: 0, count: length)
        let status = derived.withUnsafeMutableBytes { derivedBytes in
            salt.withUnsafeBytes { saltBytes in
                password.withCString { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes, password.utf8.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedBytes.bindMemory(to: UInt8.self).baseAddress, length
                    )
                }
            }
        }
        precondition(status == kCCSuccess, "PBKDF2 派生失败: \(status)")
        return derived
    }
}
