import Foundation
import Observation
import PassVaultCore
import SwiftUI

/// 全局状态：侧栏选择、列表过滤、认证缓存、锁定、增删改、导入导出。
@MainActor
@Observable
final class AppState {
    enum SidebarSelection: Hashable {
        case all
        case favorites
        case trash
        case builtIn(ItemCategory)
        case custom(UUID)
        case tag(String)
    }

    struct DecryptedFields {
        var password: String
        var notes: String
    }

    let store: VaultStore
    let crypto: CryptoService
    let settings = AppSettings()

    var items: [CredentialItem] = []
    var categories: [CustomCategory] = []
    var selection: SidebarSelection = .all
    var searchText = ""
    var selectedItemIds: Set<UUID> = []
    var selectedAccounts: [SubAccount] = []
    var revealed: Set<UUID> = []
    var revealedAccounts: Set<UUID> = []
    var globalReveal = false
    var unlockedUntil: Date?
    var toastMessage: String?
    var allTags: [String] { _allTags }

    @ObservationIgnored private var _allTags: [String] = []
    @ObservationIgnored private var activeCache: [CredentialItem] = []
    @ObservationIgnored private var trashCache: [CredentialItem] = []
    @ObservationIgnored private var accountCountCache: [UUID: Int] = [:]
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var idleTimer: Timer?

    init(store: VaultStore, crypto: CryptoService) {
        self.store = store
        self.crypto = crypto
        reloadCategories()
        refresh()
    }

    static func bootstrap() throws -> AppState {
        let key = try KeychainStore.loadOrCreateMasterKey()
        let crypto = CryptoService(key: key)
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PassVault", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let store = try VaultStore(path: support.appendingPathComponent("vault.sqlite").path)
        return AppState(store: store, crypto: crypto)
    }

    var isUnlocked: Bool { unlockedUntil.map { $0 > Date() } ?? false }

    /// 单选时的详情条目；多选时返回 nil（详情面板显示多选操作页）
    var selectedItem: CredentialItem? {
        guard selectedItemIds.count == 1, let id = selectedItemIds.first else { return nil }
        return items.first { $0.id == id }
    }

    var multiSelectedCount: Int { selectedItemIds.count }

    /// 多选的条目，按创建时间升序（最早的可作为合并保留目标）
    var multiSelectedItems: [CredentialItem] {
        items.filter { selectedItemIds.contains($0.id) }.sorted { $0.createdAt < $1.createdAt }
    }

    var trashCount: Int { trashCache.count }

    /// 是否处于"统一显示"状态：设置开启时跟随解锁状态，否则由工具栏手动开关控制
    var passwordGloballyVisible: Bool {
        settings.revealAllAfterUnlock ? isUnlocked : globalReveal
    }

    // MARK: - 列表

    func refresh() {
        var accountUsernames: [UUID: [String]] = [:]
        do {
            activeCache = try store.fetchActiveItems()
            trashCache = try store.fetchDeletedItems()
            _allTags = Array(Set(activeCache.flatMap(\.tagList))).sorted()
            let accounts = try store.fetchAllAccounts()
            accountCountCache = Dictionary(grouping: accounts, by: \.itemId).mapValues(\.count)
            for account in accounts {
                accountUsernames[account.itemId, default: []].append(account.username.lowercased())
            }
        } catch {
            showToast("读取数据失败：\(error.localizedDescription)")
            return
        }
        let base: [CredentialItem]
        switch selection {
        case .trash: base = trashCache
        case .all: base = activeCache
        case .favorites: base = activeCache.filter(\.favorite)
        case .builtIn(let c): base = activeCache.filter { $0.category == c }
        case .custom(let id): base = activeCache.filter { $0.customCategoryId == id }
        case .tag(let t): base = activeCache.filter { $0.tagList.contains(t) }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var list = base
        if !query.isEmpty {
            list = list.filter {
                $0.title.lowercased().contains(query)
                    || $0.username.lowercased().contains(query)
                    || ($0.host?.lowercased().contains(query) ?? false)
                    || ($0.url?.lowercased().contains(query) ?? false)
                    || ($0.dbType?.lowercased().contains(query) ?? false)
                    || ($0.dbName?.lowercased().contains(query) ?? false)
                    || $0.tags.lowercased().contains(query)
                    || (accountUsernames[$0.id]?.contains { $0.contains(query) } ?? false)
            }
        }
        list.sort { a, b in
            if a.favorite != b.favorite { return a.favorite }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
        items = list
        selectedItemIds = selectedItemIds.filter { id in list.contains { $0.id == id } }
    }

    /// 条目拥有的账号总数（主账号之外的附加账号数）
    func accountCount(for itemId: UUID) -> Int {
        accountCountCache[itemId] ?? 0
    }

    func reloadSelectedAccounts() {
        guard selectedItemIds.count == 1, let id = selectedItemIds.first else {
            selectedAccounts = []
            return
        }
        selectedAccounts = (try? store.fetchAccounts(itemId: id)) ?? []
    }

    func count(for sel: SidebarSelection) -> Int {
        switch sel {
        case .all: return activeCache.count
        case .favorites: return activeCache.filter(\.favorite).count
        case .trash: return trashCache.count
        case .builtIn(let c): return activeCache.filter { $0.category == c }.count
        case .custom(let id): return activeCache.filter { $0.customCategoryId == id }.count
        case .tag(let t): return activeCache.filter { $0.tagList.contains(t) }.count
        }
    }

    // MARK: - 解密与认证

    func decryptedFields(_ item: CredentialItem) -> DecryptedFields {
        var password = ""
        if !item.passwordEnc.isEmpty {
            do {
                password = try crypto.decryptString(item.passwordEnc, aad: "password:\(item.id.uuidString)")
            } catch {
                password = "（解密失败）"
            }
        }
        var notes = ""
        if let enc = item.notesEnc {
            do {
                notes = try crypto.decryptString(enc, aad: "notes:\(item.id.uuidString)")
            } catch {
                notes = "（解密失败）"
            }
        }
        return DecryptedFields(password: password, notes: notes)
    }

    @discardableResult
    func requireAuth() async -> Bool {
        if isUnlocked { return true }
        guard AuthService.canAuthenticate() else {
            showToast("本机尚未设置登录密码，无法进行身份验证。请先在「系统设置 → 用户与群组」中为账户设置密码。")
            return false
        }
        let ok = await AuthService.authenticate(reason: "在 PassVault 中查看或复制已保存的密码")
        if ok {
            unlockedUntil = Date().addingTimeInterval(Double(settings.authCacheMinutes) * 60)
        }
        return ok
    }

    func lock() {
        unlockedUntil = nil
        revealed.removeAll()
        revealedAccounts.removeAll()
        globalReveal = false
        showToast("已锁定，查看密码需重新认证")
    }

    func reveal(_ item: CredentialItem) async {
        guard await requireAuth() else { return }
        withAnimation { revealed.insert(item.id) }
    }

    func conceal(_ item: CredentialItem) {
        revealed.remove(item.id)
    }

    /// 密码是否可见：单条显示 或 全局统一显示
    func isPasswordVisible(_ item: CredentialItem) -> Bool {
        revealed.contains(item.id) || passwordGloballyVisible
    }

    /// 统一显示所有密码：需认证一次；统一模式下解锁即全局可见
    func showAllPasswords() async {
        guard await requireAuth() else { return }
        if !settings.revealAllAfterUnlock {
            globalReveal = true
        }
        showToast("已统一显示密码，锁定或认证过期后自动隐藏")
    }

    func hideAllPasswords() {
        globalReveal = false
        revealed.removeAll()
        revealedAccounts.removeAll()
        showToast("已隐藏全部密码")
    }

    // MARK: - 附加账号（一个条目多组账号）

    func decryptedAccountPassword(_ account: SubAccount) -> String {
        guard !account.passwordEnc.isEmpty else { return "" }
        do {
            return try crypto.decryptString(account.passwordEnc, aad: "account-password:\(account.id.uuidString)")
        } catch {
            return "（解密失败）"
        }
    }

    func isAccountVisible(_ account: SubAccount) -> Bool {
        revealedAccounts.contains(account.id) || passwordGloballyVisible
    }

    func revealAccount(_ account: SubAccount) async {
        guard await requireAuth() else { return }
        withAnimation { revealedAccounts.insert(account.id) }
    }

    func concealAccount(_ account: SubAccount) {
        revealedAccounts.remove(account.id)
    }

    func copyAccountPassword(_ account: SubAccount) async {
        guard await requireAuth() else { return }
        let password = decryptedAccountPassword(account)
        guard !password.isEmpty else {
            showToast("该账号没有密码")
            return
        }
        ClipboardService.copySensitive(password, clearAfter: TimeInterval(settings.clipboardClearSeconds))
        showToast(settings.clipboardClearSeconds > 0
                  ? "密码已复制，\(settings.clipboardClearSeconds) 秒后自动清除剪贴板"
                  : "密码已复制")
    }

    func copyAccountUsername(_ account: SubAccount) {
        guard !account.username.isEmpty else {
            showToast("该账号没有用户名")
            return
        }
        ClipboardService.copyPlain(account.username)
        showToast("用户名已复制")
    }

    func saveSubAccount(itemId: UUID, original: SubAccount?, username: String, password: String, note: String) {
        var account = original ?? SubAccount(
            id: UUID(), itemId: itemId, username: "", passwordEnc: Data(), note: "", createdAt: Date(), updatedAt: Date()
        )
        account.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        account.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        account.updatedAt = Date()
        do {
            account.passwordEnc = try crypto.encryptString(password, aad: "account-password:\(account.id.uuidString)")
            if original == nil {
                try store.insert(account)
            } else {
                try store.update(account)
            }
            reloadSelectedAccounts()
            refresh()
            showToast(original == nil ? "账号已添加" : "账号已保存")
        } catch {
            showToast("保存失败：\(error.localizedDescription)")
        }
    }

    func deleteSubAccount(_ account: SubAccount) {
        try? store.deleteAccount(id: account.id)
        revealedAccounts.remove(account.id)
        reloadSelectedAccounts()
        refresh()
        showToast("账号已删除")
    }

    // MARK: - 合并条目

    /// 把 others 并入 target：主账号转为附加账号、附加账号转移、条目移入回收站
    @discardableResult
    func mergeItems(target: CredentialItem, others: [CredentialItem]) -> Bool {
        let ok = performMerge(target: target, others: others)
        if ok {
            selectedItemIds = [target.id]
            refresh()
            reloadSelectedAccounts()
            showToast("已合并 \(others.count) 个条目到「\(target.title)」")
        } else {
            refresh()
        }
        return ok
    }

    /// 一键合并同标题条目组，每组保留最早创建的条目
    func mergeGroups(_ groups: [[CredentialItem]]) {
        var mergedCount = 0
        for group in groups where group.count > 1 {
            let sorted = group.sorted { $0.createdAt < $1.createdAt }
            if performMerge(target: sorted[0], others: Array(sorted[1...])) {
                mergedCount += sorted.count - 1
            }
        }
        refresh()
        showToast(mergedCount > 0 ? "已合并 \(mergedCount) 个条目" : "没有需要合并的条目")
    }

    /// 扫描同分类下标题相同（忽略大小写）的活动条目组
    func duplicateTitleGroups() -> [[CredentialItem]] {
        MergeSupport.duplicateGroups(of: activeCache)
    }

    private func performMerge(target: CredentialItem, others: [CredentialItem]) -> Bool {
        do {
            for other in others {
                if let account = try MergeSupport.makeSubAccount(from: other, targetId: target.id, crypto: crypto) {
                    try store.insert(account)
                }
                try store.reparentAccounts(from: other.id, to: target.id)
                try store.moveToTrash(id: other.id)
            }
            return true
        } catch {
            showToast("合并失败：\(error.localizedDescription)")
            return false
        }
    }

    func copyPassword(_ item: CredentialItem) async {
        guard await requireAuth() else { return }
        let password = decryptedFields(item).password
        guard !password.isEmpty else {
            showToast("该条目没有密码")
            return
        }
        ClipboardService.copySensitive(password, clearAfter: TimeInterval(settings.clipboardClearSeconds))
        showToast(settings.clipboardClearSeconds > 0
                  ? "密码已复制，\(settings.clipboardClearSeconds) 秒后自动清除剪贴板"
                  : "密码已复制")
    }

    func copyUsername(_ item: CredentialItem) {
        guard !item.username.isEmpty else {
            showToast("该条目没有用户名")
            return
        }
        ClipboardService.copyPlain(item.username)
        showToast("用户名已复制")
    }

    // MARK: - 增删改

    func save(_ draft: ItemDraft, editing original: CredentialItem?) {
        var item = original ?? CredentialItem.empty(category: draft.category)
        item.category = draft.category
        item.customCategoryId = draft.customCategoryId
        item.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        item.username = draft.username.trimmingCharacters(in: .whitespacesAndNewlines)
        item.url = draft.url.isEmpty ? nil : draft.url
        item.host = draft.host.isEmpty ? nil : draft.host
        item.port = Int(draft.port)
        item.dbType = draft.category == .database ? draft.dbType : nil
        item.dbName = draft.category == .database ? (draft.dbName.isEmpty ? nil : draft.dbName) : nil
        item.tags = draft.tags
        item.favorite = draft.favorite
        item.updatedAt = Date()
        do {
            item.passwordEnc = try crypto.encryptString(draft.password, aad: "password:\(item.id.uuidString)")
            item.notesEnc = draft.notes.isEmpty ? nil : try crypto.encryptString(draft.notes, aad: "notes:\(item.id.uuidString)")
            if original == nil {
                try store.insert(item)
            } else {
                try store.update(item)
            }
            refresh()
            showToast(original == nil ? "已添加" : "已保存")
        } catch {
            showToast("保存失败：\(error.localizedDescription)")
        }
    }

    func moveToTrash(_ item: CredentialItem) {
        try? store.moveToTrash(id: item.id)
        revealed.remove(item.id)
        refresh()
        showToast("已移到回收站")
    }

    func restore(_ item: CredentialItem) {
        try? store.restore(id: item.id)
        refresh()
        showToast("已恢复")
    }

    func deleteForever(_ item: CredentialItem) {
        try? store.deleteForever(id: item.id)
        refresh()
    }

    func emptyTrash() {
        try? store.emptyTrash()
        refresh()
        showToast("回收站已清空")
    }

    func toggleFavorite(_ item: CredentialItem) {
        try? store.setFavorite(id: item.id, favorite: !item.favorite)
        refresh()
    }

    // MARK: - 自定义分类

    func reloadCategories() {
        categories = (try? store.fetchCategories()) ?? []
    }

    func addCategory(_ name: String) {
        if (try? store.addCategory(name: name)) ?? nil == nil {
            showToast("添加失败：名称为空或已存在")
        }
        reloadCategories()
    }

    func renameCategory(_ category: CustomCategory, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != category.name else { return }
        if categories.contains(where: { $0.name == trimmed && $0.id != category.id }) {
            showToast("重命名失败：分类「\(trimmed)」已存在")
            return
        }
        try? store.renameCategory(id: category.id, to: trimmed)
        reloadCategories()
        refresh()
        showToast("已重命名为「\(trimmed)」")
    }

    /// 把条目移动到自定义分组（nil = 移出分组，仅对自定义分组生效，内置分类不变）
    func moveItem(_ item: CredentialItem, toCustomCategory id: UUID?) {
        var updated = item
        updated.customCategoryId = id
        do {
            try store.update(updated)
        } catch {
            showToast("移动失败：\(error.localizedDescription)")
            return
        }
        refresh()
        showToast(id == nil ? "已移出分组" : "已移入分组")
    }

    func deleteCategory(_ category: CustomCategory) {
        try? store.deleteCategory(id: category.id)
        if case .custom(let id) = selection, id == category.id {
            selection = .all
        }
        reloadCategories()
        refresh()
    }

    // MARK: - 导入

    @discardableResult
    func importRows(_ rows: [ImportedRow], category: ItemCategory, customCategoryId: UUID?) -> (imported: Int, skipped: Int) {
        var existing = Set(items.map { "\($0.title.lowercased())|\($0.username.lowercased())" })
        var imported = 0
        var skipped = 0
        for row in rows {
            let key = "\(row.title.lowercased())|\(row.username.lowercased())"
            if existing.contains(key) {
                skipped += 1
                continue
            }
            var item = CredentialItem.empty(category: category)
            item.customCategoryId = customCategoryId
            item.title = row.title
            item.username = row.username
            item.url = row.url.isEmpty ? nil : row.url
            item.host = row.host.isEmpty ? nil : row.host
            item.port = row.port
            item.dbName = row.dbName.isEmpty ? nil : row.dbName
            do {
                item.passwordEnc = try crypto.encryptString(row.password, aad: "password:\(item.id.uuidString)")
                item.notesEnc = row.notes.isEmpty ? nil : try crypto.encryptString(row.notes, aad: "notes:\(item.id.uuidString)")
            } catch {
                skipped += 1
                continue
            }
            try? store.insert(item)
            existing.insert(key)
            imported += 1
        }
        refresh()
        showToast("导入 \(imported) 条，跳过重复 \(skipped) 条")
        return (imported, skipped)
    }

    func exportBackup(password: String, to url: URL) -> Bool {
        let accountsByItem = Dictionary(grouping: (try? store.fetchAllAccounts()) ?? [], by: \.itemId)
        let payloadItems = activeCache.map { item -> BackupItem in
            let fields = decryptedFields(item)
            let categoryName = item.customCategoryId.flatMap { id in categories.first { $0.id == id }?.name }
            let accountPayloads = (accountsByItem[item.id] ?? []).map { account -> BackupAccount in
                BackupAccount(username: account.username, password: decryptedAccountPassword(account), note: account.note)
            }
            return BackupItem(
                category: item.category,
                customCategoryName: categoryName,
                title: item.title,
                username: item.username,
                url: item.url,
                host: item.host,
                port: item.port,
                dbType: item.dbType,
                dbName: item.dbName,
                password: fields.password,
                notes: fields.notes.isEmpty ? nil : fields.notes,
                tags: item.tags,
                favorite: item.favorite,
                createdAt: item.createdAt,
                updatedAt: item.updatedAt,
                accounts: accountPayloads.isEmpty ? nil : accountPayloads
            )
        }
        do {
            try BackupService.export(items: payloadItems, categories: categories, password: password, to: url)
            showToast("备份已导出（\(payloadItems.count) 条）")
            return true
        } catch {
            showToast("导出失败：\(error.localizedDescription)")
            return false
        }
    }

    /// 备份导入始终新增记录（新 ID），不覆盖现有数据
    func importBackup(_ payload: BackupPayload) {
        var imported = 0
        var allCategories = categories
        for backupItem in payload.items {
            var customId: UUID?
            if let name = backupItem.customCategoryName, !name.isEmpty {
                if let existing = allCategories.first(where: { $0.name == name }) {
                    customId = existing.id
                } else if let created = (try? store.addCategory(name: name)) ?? nil {
                    customId = created.id
                    allCategories.append(created)
                }
            }
            var item = CredentialItem.empty(category: backupItem.category)
            item.customCategoryId = customId
            item.title = backupItem.title
            item.username = backupItem.username
            item.url = backupItem.url
            item.host = backupItem.host
            item.port = backupItem.port
            item.dbType = backupItem.dbType
            item.dbName = backupItem.dbName
            item.tags = backupItem.tags
            item.favorite = backupItem.favorite
            item.createdAt = backupItem.createdAt
            item.updatedAt = backupItem.updatedAt
            do {
                item.passwordEnc = try crypto.encryptString(backupItem.password, aad: "password:\(item.id.uuidString)")
                item.notesEnc = try backupItem.notes.map { try crypto.encryptString($0, aad: "notes:\(item.id.uuidString)") }
                try store.insert(item)
                for backupAccount in backupItem.accounts ?? [] {
                    var account = SubAccount(
                        id: UUID(), itemId: item.id, username: backupAccount.username,
                        passwordEnc: Data(), note: backupAccount.note, createdAt: Date(), updatedAt: Date()
                    )
                    account.passwordEnc = try crypto.encryptString(backupAccount.password, aad: "account-password:\(account.id.uuidString)")
                    try store.insert(account)
                }
                imported += 1
            } catch {
                continue
            }
        }
        reloadCategories()
        refresh()
        showToast("从备份导入 \(imported) 条记录")
    }

    // MARK: - 自动锁定与提示

    func startAutoLockTimer() {
        guard idleTimer == nil else { return }
        idleTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.checkIdle() }
        }
    }

    private func checkIdle() {
        let minutes = settings.autoLockMinutes
        guard minutes > 0 else { return }
        if IdleTimeSource.secondsSinceLastInput() >= Double(minutes) * 60, isUnlocked || !revealed.isEmpty {
            lock()
        }
    }

    func showToast(_ message: String) {
        toastMessage = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled { self?.toastMessage = nil }
        }
    }
}
