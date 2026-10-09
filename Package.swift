// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PassVault",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "PassVault", targets: ["PassVault"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "PassVaultCore",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "PassVault",
            dependencies: ["PassVaultCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // 本机 CLT 缺少 XCTest 与 Testing 宏插件，测试用可执行 runner（swift run PassVaultTests）
        .executableTarget(
            name: "PassVaultTests",
            dependencies: ["PassVaultCore"],
            path: "Tests/PassVaultTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
