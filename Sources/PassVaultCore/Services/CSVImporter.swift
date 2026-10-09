import Foundation

/// 极简 CSV 解析：支持双引号包裹、引号转义、字段内换行、CRLF。
public enum CSVParser {
    public static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        let chars = Array(text)
        var i = 0

        func endField() { row.append(field); field = "" }
        func endRow() { endField(); rows.append(row); row = [] }

        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        field.append("\"")
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(c)
                }
            } else {
                switch c {
                case "\"":
                    inQuotes = true
                case ",":
                    endField()
                case "\r\n":
                    // Windows CRLF 在 Swift 中是单个字素簇（Character），需单独处理
                    endRow()
                case "\r":
                    endRow()
                case "\n":
                    endRow()
                default:
                    field.append(c)
                }
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty { endRow() }
        return rows.filter { !($0.count == 1 && $0[0].trimmingCharacters(in: .whitespaces).isEmpty) }
    }
}

public struct ImportedRow {
    public var title: String
    public var username: String
    public var password: String
    public var url: String
    public var host: String
    public var port: Int?
    public var notes: String
    public var dbName: String
}

/// CSV 导入：兼容 Chrome 密码导出与 Bitwarden 导出的表头，同时支持中文表头。
public enum CSVImporter {
    public static func map(rows: [[String]]) -> [ImportedRow] {
        guard let header = rows.first else { return [] }
        let columns = header.map(normalize)

        func index(_ candidates: [String]) -> Int? {
            columns.firstIndex { candidates.contains($0) }
        }
        func value(from row: [String], at i: Int?) -> String {
            guard let i, i < row.count else { return "" }
            return row[i].trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let titleIndex = index(["title", "name", "标题", "名称"])
        let usernameIndex = index(["username", "login_username", "user", "login", "用户名", "账号", "帐号"])
        let passwordIndex = index(["password", "login_password", "pass", "密码"])
        let urlIndex = index(["url", "login_uri", "uri", "website", "web_site", "网址", "地址", "登录网址"])
        let hostIndex = index(["host", "server", "ip", "hostname", "主机", "服务器"])
        let portIndex = index(["port", "端口"])
        let dbNameIndex = index(["database", "db_name", "dbname", "db", "数据库名", "数据库"])
        let notesIndex = index(["notes", "note", "备注", "注释", "说明"])

        var result: [ImportedRow] = []
        for row in rows.dropFirst() {
            let title = value(from: row, at: titleIndex)
            let username = value(from: row, at: usernameIndex)
            let password = value(from: row, at: passwordIndex)
            guard !title.isEmpty || !username.isEmpty || !password.isEmpty else { continue }
            result.append(ImportedRow(
                title: title.isEmpty ? username : title,
                username: username,
                password: password,
                url: value(from: row, at: urlIndex),
                host: value(from: row, at: hostIndex),
                port: Int(value(from: row, at: portIndex)),
                notes: value(from: row, at: notesIndex),
                dbName: value(from: row, at: dbNameIndex)
            ))
        }
        return result
    }

    public static func normalize(_ s: String) -> String {
        var trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("\u{FEFF}") { trimmed.removeFirst() }
        return trimmed.lowercased().replacingOccurrences(of: " ", with: "_")
    }
}
