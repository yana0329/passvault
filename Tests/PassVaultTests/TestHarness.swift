import Foundation

// 极简测试 harness：断言计数 + 失败清单 + 退出码（零宏依赖，规避本机 CLT 宏插件缺失问题）

var totalChecks = 0
var totalFailures: [String] = []
var currentSuite = ""

@discardableResult
func check(_ cond: Bool, _ message: String = "", file: String = #fileID, line: UInt = #line) -> Bool {
    totalChecks += 1
    if cond { return true }
    totalFailures.append("[\(currentSuite)] \(message) — \(file):\(line)")
    print("   ❌ \(message) (\(file):\(line))")
    return false
}

func expectThrows(_ body: () throws -> Void, message: String = "", file: String = #fileID, line: UInt = #line) {
    do {
        try body()
        check(false, "期望抛出异常但未抛出 \(message)", file: file, line: line)
    } catch {
        check(true, message, file: file, line: line)
    }
}

func expectThrows<T: Error & Equatable>(_ expected: T, _ body: () throws -> Void, message: String = "", file: String = #fileID, line: UInt = #line) {
    do {
        try body()
        check(false, "期望抛出异常但未抛出 \(message)", file: file, line: line)
    } catch {
        check((error as? T) == expected, "期望 \(expected)，实际 \(error) \(message)", file: file, line: line)
    }
}

func runSuite(_ name: String, _ body: () throws -> Void) {
    currentSuite = name
    let before = totalFailures.count
    do {
        try body()
    } catch {
        totalFailures.append("[\(name)] 未捕获异常: \(error)")
        print("   ❌ 未捕获异常: \(error)")
    }
    let failed = totalFailures.count - before
    print(failed == 0 ? "✅ \(name)" : "❌ \(name)（\(failed) 项失败）")
}
