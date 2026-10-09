#!/bin/zsh
# 构建 PassVault.app：release 编译 → 组装 bundle → 生成图标 → ad-hoc 签名
#
# 注意：本机 CLT 的 macOS 27 SDK 把 @State 等 SwiftUI 属性包装器改为宏实现，
# 但 CLT 未附带 SwiftUIMacros 宏插件，因此必须用 macOS 26.5 SDK 构建。
set -euo pipefail
cd "$(dirname "$0")/.."

export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
APP_NAME="PassVault"
APP="build/${APP_NAME}.app"

swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/${APP_NAME}" "$APP/Contents/MacOS/${APP_NAME}"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>PassVault</string>
    <key>CFBundleDisplayName</key><string>PassVault 密库</string>
    <key>CFBundleIdentifier</key><string>com.hc.passvault</string>
    <key>CFBundleExecutable</key><string>PassVault</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
</dict>
</plist>
PLIST

if [ ! -f "$APP/Contents/Resources/AppIcon.icns" ]; then
  echo "生成应用图标…"
  swift scripts/make_icon.swift "$APP/Contents/Resources"
fi

codesign --force --sign - "$APP"

echo "✅ 构建完成: $APP"
echo "   打开运行: open $APP"
