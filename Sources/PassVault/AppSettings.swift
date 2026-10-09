import Foundation
import Observation

/// 应用偏好设置（UserDefaults 持久化，不含敏感数据）
@MainActor
@Observable
final class AppSettings {
    private let defaults: UserDefaults

    /// 空闲多少分钟后自动锁定，0 = 从不
    var autoLockMinutes: Int { didSet { defaults.set(autoLockMinutes, forKey: "pv.autoLockMinutes") } }
    /// 认证通过后的免认证缓存时长，0 = 每次都要求认证
    var authCacheMinutes: Int { didSet { defaults.set(authCacheMinutes, forKey: "pv.authCacheMinutes") } }
    /// 复制密码后多少秒清除剪贴板，0 = 不清除
    var clipboardClearSeconds: Int { didSet { defaults.set(clipboardClearSeconds, forKey: "pv.clipboardClearSeconds") } }
    /// 解锁后统一显示所有密码（false = 逐条点击显示）
    var revealAllAfterUnlock: Bool { didSet { defaults.set(revealAllAfterUnlock, forKey: "pv.revealAllAfterUnlock") } }

    static let autoLockChoices: [(value: Int, label: String)] = [
        (0, "从不"), (1, "1 分钟"), (5, "5 分钟"), (10, "10 分钟"), (30, "30 分钟")
    ]
    static let authCacheChoices: [(value: Int, label: String)] = [
        (0, "每次都要求认证"), (1, "1 分钟"), (5, "5 分钟"), (15, "15 分钟")
    ]
    static let clipboardChoices: [(value: Int, label: String)] = [
        (0, "不清除"), (15, "15 秒"), (30, "30 秒"), (60, "60 秒")
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        autoLockMinutes = defaults.object(forKey: "pv.autoLockMinutes") as? Int ?? 10
        authCacheMinutes = defaults.object(forKey: "pv.authCacheMinutes") as? Int ?? 5
        clipboardClearSeconds = defaults.object(forKey: "pv.clipboardClearSeconds") as? Int ?? 30
        revealAllAfterUnlock = defaults.object(forKey: "pv.revealAllAfterUnlock") as? Bool ?? false
    }
}
