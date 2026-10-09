import CryptoKit
import Foundation
import PassVaultCore

func cryptoTests() {
    let crypto = CryptoService(key: SymmetricKey(size: .bits256))

    // 加解密回环
    let cases = ["hello", "密码123!@#", "", String(repeating: "x", count: 10_000)]
    for (i, plain) in cases.enumerated() {
        let encrypted = try! crypto.encryptString(plain, aad: "password:id-\(i)")
        check(Data(plain.utf8) != encrypted, "密文不应等于明文（case \(i)）")
        let decrypted = try! crypto.decryptString(encrypted, aad: "password:id-\(i)")
        check(decrypted == plain, "解密结果应与明文一致（case \(i)）")
    }

    // AAD 不匹配应失败
    let encrypted = try! crypto.encryptString("secret", aad: "password:a")
    expectThrows({
        _ = try crypto.decryptString(encrypted, aad: "password:b")
    }, message: "AAD 不匹配时解密应抛错")

    // 篡改密文应失败
    var tampered = try! crypto.encryptString("secret", aad: "password:a")
    tampered[tampered.count - 1] ^= 0xFF
    expectThrows({
        _ = try crypto.decryptString(tampered, aad: "password:a")
    }, message: "密文被篡改时解密应抛错")
}

func pbkdf2Tests() {
    // PBKDF2-HMAC-SHA256 公开测试向量（password="password", salt="salt", 1 次迭代, 32 字节）
    let key = CryptoService.deriveKey(password: "password", salt: Data("salt".utf8), iterations: 1, length: 32)
    let hex = key.map { String(format: "%02x", $0) }.joined()
    check(hex == "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b", "PBKDF2 标准测试向量不符: \(hex)")

    let salt = Data(repeating: 7, count: 16)
    let a = CryptoService.deriveKey(password: "pw", salt: salt, iterations: 1000)
    let b = CryptoService.deriveKey(password: "pw", salt: salt, iterations: 1000)
    check(a == b, "相同输入派生结果应一致")
    check(a != CryptoService.deriveKey(password: "pw2", salt: salt, iterations: 1000), "不同密码派生结果应不同")
    check(a != CryptoService.deriveKey(password: "pw", salt: Data(repeating: 8, count: 16), iterations: 1000), "不同盐派生结果应不同")
    check(a.count == 32, "派生密钥长度应为 32 字节")
}
