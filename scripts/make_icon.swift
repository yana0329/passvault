// 生成 PassVault 应用图标（SF Symbol key.fill + 渐变圆角矩形），输出 AppIcon.icns
// 用法: swift scripts/make_icon.swift <输出目录>
import AppKit

let outputDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "."

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024)
]

func renderIcon(size pixels: Int) -> NSBitmapImageRep? {
    let size = CGFloat(pixels)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        NSGraphicsContext.restoreGraphicsState()
        return nil
    }
    NSGraphicsContext.current = context

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let inset = size * 0.09
    let rounded = NSBezierPath(
        roundedRect: rect.insetBy(dx: inset, dy: inset),
        xRadius: size * 0.185,
        yRadius: size * 0.185
    )

    // 渐变底色：靛蓝 → 深紫
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.18, green: 0.34, blue: 0.90, alpha: 1),
        NSColor(calibratedRed: 0.42, green: 0.22, blue: 0.82, alpha: 1)
    ])
    gradient?.draw(in: rounded, angle: -55)

    // 白色钥匙符号
    let pointSize = size * 0.42
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
    if let symbol = NSImage(systemSymbolName: "key.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let white = NSImage(size: symbol.size, flipped: false) { _ in
            symbol.draw(in: NSRect(origin: .zero, size: symbol.size))
            NSColor.white.set()
            NSRect(origin: .zero, size: symbol.size).fill(using: .sourceAtop)
            return true
        }
        let scale = min(size * 0.52 / white.size.width, size * 0.52 / white.size.height)
        let w = white.size.width * scale
        let h = white.size.height * scale
        white.draw(
            in: NSRect(x: (size - w) / 2, y: (size - h) / 2, width: w, height: h),
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0
        )
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let iconsetURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("PassVault.iconset")
try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

for (name, pixels) in sizes {
    guard let rep = renderIcon(size: pixels),
          let png = rep.representation(using: .png, properties: [:]) else {
        fputs("❌ 渲染 \(name) 失败\n", stderr)
        exit(1)
    }
    let fileURL = iconsetURL.appendingPathComponent("\(name).png")
    try png.write(to: fileURL)
}

let icnsURL = URL(fileURLWithPath: outputDir).appendingPathComponent("AppIcon.icns")
try? FileManager.default.removeItem(at: icnsURL)

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    fputs("❌ iconutil 失败\n", stderr)
    exit(1)
}
print("✅ 图标已生成: \(icnsURL.path)")
