import Foundation
import Security

/// 密码生成器：使用 SecRandom（密码学安全随机源），保证每个被选中的字符集至少出现一次。
public enum PasswordGenerator {
    public struct Options {
        public var length: Int
        public var uppercase: Bool
        public var lowercase: Bool
        public var digits: Bool
        public var symbols: Bool
        public var excludeAmbiguous: Bool

        public init(
            length: Int = 20,
            uppercase: Bool = true,
            lowercase: Bool = true,
            digits: Bool = true,
            symbols: Bool = true,
            excludeAmbiguous: Bool = true
        ) {
            self.length = length
            self.uppercase = uppercase
            self.lowercase = lowercase
            self.digits = digits
            self.symbols = symbols
            self.excludeAmbiguous = excludeAmbiguous
        }

        public var hasAnySet: Bool { uppercase || lowercase || digits || symbols }
    }

    public static let ambiguousCharacters: Set<Character> = ["O", "0", "o", "I", "l", "1"]

    public static func generate(options: Options) -> String {
        let uppercasePool = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let lowercasePool = Array("abcdefghijklmnopqrstuvwxyz")
        let digitPool = Array("0123456789")
        let symbolPool = Array("!@#$%^&*-_=+?")

        func filtered(_ pool: [Character]) -> [Character] {
            options.excludeAmbiguous ? pool.filter { !ambiguousCharacters.contains($0) } : pool
        }

        var groups: [[Character]] = []
        if options.uppercase { groups.append(filtered(uppercasePool)) }
        if options.lowercase { groups.append(filtered(lowercasePool)) }
        if options.digits { groups.append(filtered(digitPool)) }
        if options.symbols { groups.append(symbolPool) }
        groups = groups.filter { !$0.isEmpty }
        guard options.hasAnySet, !groups.isEmpty, options.length >= groups.count else { return "" }

        var characters = groups.map { $0[randomIndex($0.count)] }
        let combined = Array(groups.joined())
        while characters.count < options.length {
            characters.append(combined[randomIndex(combined.count)])
        }
        for i in stride(from: characters.count - 1, to: 0, by: -1) {
            let j = randomIndex(i + 1)
            characters.swapAt(i, j)
        }
        return String(characters.prefix(options.length))
    }

    /// 拒绝采样，保证 [0, bound) 均匀分布
    public static func randomIndex(_ bound: Int) -> Int {
        precondition(bound > 0 && bound <= Int(UInt32.max))
        let limit = UInt32.max - (UInt32.max % UInt32(bound))
        var value: UInt32 = 0
        repeat {
            _ = SecRandomCopyBytes(kSecRandomDefault, 4, &value)
        } while value >= limit
        return Int(value % UInt32(bound))
    }

    public static func strengthLabel(_ password: String) -> String {
        guard !password.isEmpty else { return "未设置" }
        let classes = [
            password.contains { $0.isUppercase },
            password.contains { $0.isLowercase },
            password.contains { $0.isNumber },
            password.contains { !$0.isLetter && !$0.isNumber }
        ].filter { $0 }.count
        var score = 0
        if password.count >= 12 { score += 1 }
        if password.count >= 20 { score += 1 }
        if classes >= 3 { score += 1 }
        if classes >= 4 { score += 1 }
        return score <= 1 ? "弱" : (score == 2 ? "中" : "强")
    }
}
