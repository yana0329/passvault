import Foundation

setvbuf(stdout, nil, _IONBF, 0)

runSuite("CryptoService 加密回环") { cryptoTests() }
runSuite("PBKDF2 派生") { pbkdf2Tests() }
runSuite("CSVParser 解析") { csvParserTests() }
runSuite("CSVImporter 表头映射") { csvImporterTests() }
runSuite("URLNormalizer 域名提取") { urlNormalizerTests() }
runSuite("MergeSupport 合并") { mergeSupportTests() }
runSuite("PasswordGenerator 生成器") { passwordGeneratorTests() }
runSuite("VaultStore 数据层") { try vaultStoreTests() }
runSuite("BackupService 备份") { try backupServiceTests() }

print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("断言 \(totalChecks) 项，失败 \(totalFailures.count) 项")
if totalFailures.isEmpty {
    print("✅ 全部通过")
    exit(0)
} else {
    for failure in totalFailures { print("  " + failure) }
    print("❌ 存在失败")
    exit(1)
}
