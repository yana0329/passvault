import Foundation

/// 网址归一化：从任意 URL 字符串提取用于分组的主机名
/// （去掉协议、路径、端口、userinfo 和 www. 前缀，统一小写）
public enum URLNormalizer {
    public static func host(from urlString: String) -> String {
        var s = urlString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !s.isEmpty else { return "" }
        if let idx = s.range(of: "://") {
            s = String(s[idx.upperBound...])
        } else if s.hasPrefix("//") {
            s = String(s.dropFirst(2))
        }
        if let idx = s.firstIndex(of: "@") {
            s = String(s[s.index(after: idx)...])
        }
        if let idx = s.firstIndex(of: "/") {
            s = String(s[..<idx])
        }
        if let idx = s.firstIndex(of: "?") {
            s = String(s[..<idx])
        }
        if let idx = s.firstIndex(of: ":") {
            s = String(s[..<idx])
        }
        if s.hasPrefix("www.") {
            s = String(s.dropFirst(4))
        }
        return s
    }
}
