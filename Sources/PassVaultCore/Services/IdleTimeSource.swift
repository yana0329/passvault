import CoreGraphics
import Foundation

/// 读取本会话用户输入空闲时长，用于自动锁定。无需辅助功能权限。
public enum IdleTimeSource {
    public static func secondsSinceLastInput() -> TimeInterval {
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }
}
