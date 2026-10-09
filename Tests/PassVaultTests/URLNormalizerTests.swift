import Foundation
import PassVaultCore

func urlNormalizerTests() {
    check(URLNormalizer.host(from: "https://github.com/login") == "github.com", "标准 https 网址: \(URLNormalizer.host(from: "https://github.com/login"))")
    check(URLNormalizer.host(from: "http://GitHub.com") == "github.com", "大小写归一")
    check(URLNormalizer.host(from: "https://www.GitHub.com/x?y=1") == "github.com", "去 www 与参数")
    check(URLNormalizer.host(from: "https://10.0.0.5:8080/admin") == "10.0.0.5", "IP 带端口")
    check(URLNormalizer.host(from: "http://10.0.0.5") == "10.0.0.5", "纯 IP")
    check(URLNormalizer.host(from: "github.com") == "github.com", "无协议网址")
    check(URLNormalizer.host(from: "//cdn.example.com/a.js") == "cdn.example.com", "协议相对地址")
    check(URLNormalizer.host(from: "https://user@mail.example.com") == "mail.example.com", "去 userinfo")
    check(URLNormalizer.host(from: "  https://a.com  ") == "a.com", "首尾空白")
    check(URLNormalizer.host(from: "") == "", "空串返回空")
    check(URLNormalizer.host(from: "不是网址") == "不是网址", "非网址原样返回（归入未填写以外的兜底组）")
}
