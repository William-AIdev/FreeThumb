import AppKit
import Foundation

let canvasSize = NSSize(width: 720, height: 480)
let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let appIconURL = URL(fileURLWithPath: CommandLine.arguments[2])

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
  NSColor(srgbRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func drawText(
  _ text: String,
  in rect: NSRect,
  font: NSFont,
  color: NSColor,
  alignment: NSTextAlignment = .left
) {
  let paragraph = NSMutableParagraphStyle()
  paragraph.alignment = alignment
  paragraph.lineBreakMode = .byTruncatingTail
  text.draw(
    in: rect,
    withAttributes: [
      .font: font,
      .foregroundColor: color,
      .paragraphStyle: paragraph,
    ]
  )
}

let image = NSImage(size: canvasSize)
image.lockFocus()

let fullRect = NSRect(origin: .zero, size: canvasSize)
NSGradient(
  colors: [color(7, 13, 27), color(12, 25, 49), color(5, 10, 20)]
)?.draw(in: fullRect, angle: -28)

let glow = NSBezierPath(ovalIn: NSRect(x: 455, y: 190, width: 360, height: 360))
color(23, 120, 255, 0.13).setFill()
glow.fill()

for offset in stride(from: CGFloat(0), through: 96, by: 24) {
  let path = NSBezierPath()
  path.move(to: NSPoint(x: -20, y: 330 - offset))
  path.curve(
    to: NSPoint(x: 740, y: 395 - offset),
    controlPoint1: NSPoint(x: 190, y: 440 - offset),
    controlPoint2: NSPoint(x: 480, y: 270 - offset)
  )
  path.lineWidth = 1
  color(97, 176, 255, 0.08).setStroke()
  path.stroke()
}

if let icon = NSImage(contentsOf: appIconURL) {
  icon.draw(
    in: NSRect(x: 34, y: 388, width: 58, height: 58),
    from: .zero,
    operation: .sourceOver,
    fraction: 1
  )
}

drawText(
  "FreeThumb",
  in: NSRect(x: 108, y: 410, width: 280, height: 34),
  font: .systemFont(ofSize: 25, weight: .bold),
  color: .white
)
drawText(
  "Keep long-running work awake",
  in: NSRect(x: 109, y: 390, width: 340, height: 22),
  font: .systemFont(ofSize: 13, weight: .medium),
  color: color(177, 201, 232)
)

drawText(
  "Drag FreeThumb to Applications",
  in: NSRect(x: 120, y: 334, width: 480, height: 30),
  font: .systemFont(ofSize: 22, weight: .semibold),
  color: .white,
  alignment: .center
)
drawText(
  "将 FreeThumb 拖到 Applications 文件夹",
  in: NSRect(x: 120, y: 310, width: 480, height: 22),
  font: .systemFont(ofSize: 14, weight: .medium),
  color: color(150, 189, 235),
  alignment: .center
)

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 292, y: 237))
arrow.line(to: NSPoint(x: 420, y: 237))
arrow.move(to: NSPoint(x: 398, y: 253))
arrow.line(to: NSPoint(x: 420, y: 237))
arrow.line(to: NSPoint(x: 398, y: 221))
arrow.lineWidth = 5
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
color(55, 153, 255).setStroke()
arrow.stroke()

drawText(
  "DRAG TO INSTALL",
  in: NSRect(x: 292, y: 262, width: 128, height: 18),
  font: .systemFont(ofSize: 10, weight: .bold),
  color: color(114, 186, 255),
  alignment: .center
)

let warningRect = NSRect(x: 28, y: 24, width: 664, height: 116)
let warningPath = NSBezierPath(roundedRect: warningRect, xRadius: 18, yRadius: 18)
color(255, 255, 255, 0.07).setFill()
warningPath.fill()
color(255, 255, 255, 0.13).setStroke()
warningPath.lineWidth = 1
warningPath.stroke()

if let shield = NSImage(
  systemSymbolName: "lock.shield.fill",
  accessibilityDescription: nil
)?.withSymbolConfiguration(.init(pointSize: 23, weight: .semibold)) {
  let tinted = shield.withSymbolConfiguration(.init(paletteColors: [color(255, 193, 73)])) ?? shield
  tinted.draw(in: NSRect(x: 48, y: 85, width: 28, height: 28))
}

drawText(
  "If macOS cannot verify FreeThumb",
  in: NSRect(x: 88, y: 92, width: 570, height: 24),
  font: .systemFont(ofSize: 15, weight: .semibold),
  color: .white
)
drawText(
  "Do not move it to Trash. Open System Settings → Privacy & Security → Open Anyway.",
  in: NSRect(x: 88, y: 66, width: 570, height: 22),
  font: .systemFont(ofSize: 12, weight: .medium),
  color: color(218, 225, 238)
)
drawText(
  "不要移到废纸篓。前往“系统设置 → 隐私与安全性”，选择“仍要打开”。",
  in: NSRect(x: 88, y: 42, width: 570, height: 22),
  font: .systemFont(ofSize: 12, weight: .medium),
  color: color(167, 195, 230)
)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
  let representation = NSBitmapImageRep(data: tiff),
  let png = representation.representation(using: .png, properties: [:])
else {
  fatalError("Unable to render DMG background")
}

try FileManager.default.createDirectory(
  at: outputURL.deletingLastPathComponent(),
  withIntermediateDirectories: true
)
try png.write(to: outputURL)
