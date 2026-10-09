import Foundation
import PassVaultCore

func passwordGeneratorTests() {
    for length in [8, 12, 20, 64] {
        let password = PasswordGenerator.generate(options: .init(length: length))
        check(password.count == length, "生成长度应为 \(length)，实际 \(password.count)")
    }

    let limited = PasswordGenerator.generate(options: .init(length: 30, uppercase: false, lowercase: true, digits: true, symbols: false))
    check(limited.allSatisfy { $0.isLowercase || $0.isNumber }, "只应包含小写与数字")
    check(!limited.contains { $0.isUppercase }, "不应包含大写字母")

    for _ in 0..<50 {
        let password = PasswordGenerator.generate(options: .init(length: 40, excludeAmbiguous: true))
        for c in password {
            check(!PasswordGenerator.ambiguousCharacters.contains(c), "不应包含易混淆字符 \(c)")
        }
    }

    for _ in 0..<50 {
        let password = PasswordGenerator.generate(options: .init(length: 20))
        check(password.contains { $0.isUppercase }, "应包含大写字母")
        check(password.contains { $0.isLowercase }, "应包含小写字母")
        check(password.contains { $0.isNumber }, "应包含数字")
        check(password.contains { !$0.isLetter && !$0.isNumber }, "应包含符号")
    }

    let empty = PasswordGenerator.generate(options: .init(uppercase: false, lowercase: false, digits: false, symbols: false))
    check(empty == "", "未选字符集时应返回空串")

    // 分布粗检：200 个 4 位密码首位字符应多样
    var firstChars = Set<Character>()
    for _ in 0..<200 {
        let password = PasswordGenerator.generate(options: .init(length: 4))
        if let first = password.first { firstChars.insert(first) }
    }
    check(firstChars.count > 20, "随机分布过于集中（首位仅 \(firstChars.count) 种）")

    check(PasswordGenerator.strengthLabel("") == "未设置", "空密码强度标签")
    check(PasswordGenerator.strengthLabel("12345678") == "弱", "短数字密码应为弱")
    check(["弱", "中"].contains(PasswordGenerator.strengthLabel("abcdefghij1234")), "中等密码标签")
    check(PasswordGenerator.strengthLabel("Ab3$efghijklmnopqrst") == "强", "复杂长密码应为强")
}
