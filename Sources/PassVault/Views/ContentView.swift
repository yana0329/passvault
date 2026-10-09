import Combine
import PassVaultCore
import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var state
    @State private var editTarget: EditTarget?
    @State private var generatorContext: GeneratorContext?

    var body: some View {
        @Bindable var state = state
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 190, ideal: 225)
        } content: {
            ItemListView()
                .navigationSplitViewColumnWidth(min: 300, ideal: 360)
        } detail: {
            DetailView()
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    editTarget = EditTarget(original: nil)
                } label: {
                    Label("新建条目", systemImage: "plus")
                }
                .help("新建账号密码条目 (⌘N)")

                Button {
                    generatorContext = GeneratorContext(initialPassword: "")
                } label: {
                    Label("密码生成器", systemImage: "wand.and.stars")
                }
                .help("打开密码生成器")

                Button {
                    if state.passwordGloballyVisible {
                        state.hideAllPasswords()
                    } else {
                        Task { await state.showAllPasswords() }
                    }
                } label: {
                    Label(
                        state.passwordGloballyVisible ? "隐藏全部密码" : "显示全部密码",
                        systemImage: state.passwordGloballyVisible ? "eye.slash" : "eye"
                    )
                }
                .help(state.passwordGloballyVisible
                      ? "隐藏所有密码，恢复掩码显示"
                      : "认证一次后统一显示所有密码（无需逐条点击）")

                Button {
                    state.lock()
                } label: {
                    Label("锁定", systemImage: "lock.fill")
                }
                .help("隐藏已显示的密码并要求重新认证 (⌘L)")
            }
        }
        .sheet(item: $editTarget) { target in
            EditSheet(original: target.original)
        }
        .sheet(item: $generatorContext) { context in
            GeneratorSheet(initialPassword: context.initialPassword)
        }
        .onAppear { state.startAutoLockTimer() }
        .onReceive(NotificationCenter.default.publisher(for: .pvNewItem)) { _ in
            editTarget = EditTarget(original: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: .pvEditItem)) { notification in
            if let item = notification.object as? CredentialItem {
                editTarget = EditTarget(original: item)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pvLock)) { _ in
            state.lock()
        }
        .overlay(alignment: .bottom) {
            toastView.animation(.easeOut(duration: 0.25), value: state.toastMessage)
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let message = state.toastMessage {
            Text(message)
                .font(.callout)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.separator))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
