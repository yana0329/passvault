import Foundation
import PassVaultCore

func csvParserTests() {
    let rows = CSVParser.parse("name,url,username,password\nGitHub,https://github.com,me,pass1\nGitLab,https://gitlab.com,you,\"pass,2\"")
    check(rows.count == 3, "应解析出 3 行，实际 \(rows.count)")
    check(rows[0] == ["name", "url", "username", "password"], "表头应正确")
    check(rows[2][3] == "pass,2", "引号包裹的逗号字段应正确: \(rows[2][3])")

    let quoted = CSVParser.parse("a,b\n\"line1\nline2\",\"say \"\"hi\"\"\"\r\nx,y")
    check(quoted.count == 3, "含引号换行的行数应正确")
    check(quoted[1][0] == "line1\nline2", "字段内换行应保留")
    check(quoted[1][1] == "say \"hi\"", "转义引号应还原")
    check(quoted[2] == ["x", "y"], "CRLF 行应正确")

    let crlf = CSVParser.parse("h1,h2\r\n1,2\r\n\r\n")
    check(crlf.count == 2, "末尾空行应过滤，实际 \(crlf.count)")
}

func csvImporterTests() {
    // Chrome 导出格式
    let chrome = CSVImporter.map(rows: CSVParser.parse("name,url,username,password,note\nGitHub,https://github.com,octocat,hunter2,some note"))
    check(chrome.count == 1, "Chrome CSV 应映射 1 条")
    check(chrome[0].title == "GitHub" && chrome[0].url == "https://github.com", "Chrome 标题/网址映射")
    check(chrome[0].username == "octocat" && chrome[0].password == "hunter2", "Chrome 用户名/密码映射")
    check(chrome[0].notes == "some note", "Chrome 备注映射")

    // Bitwarden 导出格式
    let bitwarden = CSVImporter.map(rows: CSVParser.parse("folder,favorite,type,name,notes,fields,reprompt,login_uri,login_username,login_password,login_totp\n,,login,GitHub,,\"\",0,https://github.com,me,p@ss,"))
    check(bitwarden.count == 1, "Bitwarden CSV 应映射 1 条")
    check(bitwarden[0].title == "GitHub" && bitwarden[0].username == "me" && bitwarden[0].password == "p@ss", "Bitwarden 字段映射")

    // 中文表头
    let chinese = CSVImporter.map(rows: CSVParser.parse("标题,用户名,密码,网址,备注\n网站A,admin,123456,https://a.com,备注A"))
    check(chinese[0].title == "网站A" && chinese[0].username == "admin" && chinese[0].password == "123456", "中文表头映射")

    // 服务器表头（host/ip/port/database）
    let server = CSVImporter.map(rows: CSVParser.parse("name,ip,port,database,username,password\nweb-1,10.0.0.5,22,orders,root,toor"))
    check(server[0].host == "10.0.0.5" && server[0].port == 22, "服务器 host/port 映射")
    check(server[0].dbName == "orders", "数据库名映射")

    // BOM 处理
    let bom = CSVImporter.map(rows: CSVParser.parse("\u{FEFF}name,username,password\nA,u,p"))
    check(bom[0].title == "A", "应剥离 UTF-8 BOM")
}
