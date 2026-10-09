import AppKit
import PassVaultCore
import SwiftUI

/// 关闭最后一个窗口即退出应用：避免 SwiftUI 默认驻留后台导致"点图标打不开"，
/// 同时退出即清空认证缓存，更符合密码管理器的安全预期。
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct PassVaultApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private enum BootState {
        case ready(AppState)
        case failed(String)
    }

    @State private var boot: BootState

    init() {
        do {
            _boot = State(initialValue: .ready(try AppState.bootstrap()))
        } catch {
            _boot = State(initialValue: .failed(String(describing: error)))
        }
    }

    var body: some Scene {
        WindowGroup("PassVault 密库") {
            switch boot {
            case .ready(let state):
                ContentView()
                    .environment(state)
                    .frame(minWidth: 1020, minHeight: 640)
            case .failed(let message):
                StartupErrorView(message: message)
            }
        }
        .defaultSize(width: 1180, height: 760)

        Settings {
            if case .ready(let state) = boot {
                SettingsView()
                    .environment(state)
                    .frame(width: 520, height: 420)
            }
        }
        .commands {
            CommandMenu("密码库") {
                Button("新建条目") {
                    NotificationCenter.default.post(name: .pvNewItem, object: nil)
                }
                .keyboardShortcut("n")
                Button("锁定") {
                    NotificationCenter.default.post(name: .pvLock, object: nil)
                }
                .keyboardShortcut("l")
            }
        }
    }
}

extension Notification.Name {
    static let pvNewItem = Notification.Name("pvNewItem")
    static let pvLock = Notification.Name("pvLock")
    static let pvEditItem = Notification.Name("pvEditItem")
}

struct StartupErrorView: View {
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label("无法启动", systemImage: "exclamationmark.triangle")
        } description: {
            Text("初始化失败：\(message)\n\n可能原因：系统刚唤醒（钥匙串尚未解锁）或钥匙串授权被拒绝，请重新打开应用。")
        }
        .frame(width: 480)
    }
}
