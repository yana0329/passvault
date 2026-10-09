# PassVault 密库

macOS 原生账号密码管理工具（Swift + SwiftUI）。保存浏览器、服务器、数据库及其他账号密码；查看/复制密码需要 **Touch ID 指纹或系统登录密码** 认证。

## 功能

- 三栏界面：侧栏分类（浏览器/服务器/数据库/其他 + 自定义分类 + 标签）｜条目列表｜详情面板
- 一个标题多组账号：条目下可添加任意多组附加账号（用户名+密码+备注），列表显示账号数角标，附加账号随备份保存
- 条目合并：列表 ⌘ 多选后右键「合并所选条目」（可选保留条目），或 设置 → 数据 →「合并同标题条目」一键按组合并；并入条目移入回收站
- 分组显示：浏览器分类按网址域名归组，服务器/数据库分类按主机 IP 归组
- 分类管理：设置 → 分类 可添加/重命名/删除自定义分类（含条目计数与删除确认），侧栏右键快捷管理；条目右键可批量移动到分组
- 条目增删改查、收藏、搜索、回收站（软删除、彻底删除、清空）
- 按分类动态表单：浏览器 → 网址；服务器 → 主机/端口；数据库 → 类型/主机/端口
- 查看密码、复制密码、查看备注均需本机认证（Touch ID 优先，失败回退系统密码）
- 密码统一显示：设置中可选「解锁后统一显示」，认证一次后所有密码明文可见；工具栏眼睛按钮可随时临时开关；锁定或认证过期自动恢复掩码
- 密码生成器（长度/字符集/排除易混淆字符，SecRandom 安全随机）
- 自动锁定（空闲 N 分钟）、认证缓存（默认 5 分钟内免重复认证）
- 剪贴板保护：复制密码后延时自动清除，写入 Concealed 标记
- CSV 导入（Chrome / Bitwarden / 1Password / 中文表头，重复条目跳过）
- 加密备份导出/导入（.pvbak，PBKDF2-SHA256 派生密钥 + AES-256-GCM）

## 安全模型

| 层 | 机制 |
|---|---|
| 主密钥 | 随机 32 字节，存 macOS 钥匙串（`WhenUnlockedThisDeviceOnly`，不随 iCloud/备份同步） |
| 数据加密 | 每条记录的密码、备注字段用 AES-256-GCM 加密后落库，AAD 绑定记录 ID 防移植 |
| 查看认证 | `LAContext(.deviceOwnerAuthentication)`：Touch ID → 系统密码，设备未设密码则拒绝使用 |
| 备份 | 用户输入的备份密码经 PBKDF2（210k 次迭代）派生密钥加密全量 JSON |
| 元数据 | 标题/用户名/主机/网址/标签明文存储（支持 SQLite 搜索），密码与备注始终密文 |

数据文件：`~/Library/Application Support/PassVault/vault.sqlite`
主密钥：本机钥匙串（换机不可迁移，恢复数据请用「设置 → 数据 → 导出加密备份」）

## 构建与运行

需要 macOS 14+ 与 Xcode Command Line Tools（无需完整 Xcode）。

**本机工具链注意**（重要）：这台机器的 CLT 使用 macOS 27 SDK，该 SDK 把 `@State` 等 SwiftUI
属性包装器改成了宏实现，但 CLT 未附带 `SwiftUIMacros` 宏插件；同时 CLT 也没有 XCTest 框架。
因此本项目固定：

- 构建必须用 macOS 26.5 SDK：`export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk`
- 测试是可执行 runner（零宏依赖）：`swift run PassVaultTests`（断言计数 + 失败清单 + 退出码）

```bash
# 开发运行
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift run

# 测试（2270+ 项断言）
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift run PassVaultTests

# 打包成 App（release 构建 + 图标 + ad-hoc 签名，脚本内部已设置 SDKROOT）
./scripts/build_app.sh
open build/PassVault.app
```

首次拉取 GRDB 依赖如超时，使用代理：

```bash
HTTPS_PROXY=http://127.0.0.1:7897 swift build
```

## 注意事项

- **钥匙串授权**：首次访问主密钥时系统可能弹出授权框，点「始终允许」。开发期每次重新编译后二进制签名变化，可能需要再授权一次。
- **系统必须设置登录密码**：否则无法进行认证，查看密码功能会提示先去系统设置设置密码。
- 自动锁定 = 清空认证缓存并隐藏已显示的密码；标题/用户名等元数据按设计保持可见（便于搜索）。
