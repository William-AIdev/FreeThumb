import AppKit
import SwiftUI

@main
struct FreeThumbApp: App {
  @StateObject private var controller = AppController()

  var body: some Scene {
    MenuBarExtra {
      MenuBarContentView(controller: controller)
    } label: {
      Image(nsImage: menuBarImage)
        .accessibilityLabel(controller.menuBarAccessibilityLabel)
    }
    .menuBarExtraStyle(.window)
  }

  private var menuBarImage: NSImage {
    let image =
      NSImage(
        systemSymbolName: controller.menuBarIconName,
        accessibilityDescription: controller.menuBarAccessibilityLabel
      ) ?? NSImage()

    guard let color = menuBarColor else {
      image.isTemplate = true
      return image
    }

    let configuration = NSImage.SymbolConfiguration(paletteColors: [color])
    let coloredImage = image.withSymbolConfiguration(configuration) ?? image
    coloredImage.isTemplate = false
    return coloredImage
  }

  private var menuBarColor: NSColor? {
    switch controller.menuBarStatus {
    case .inactive: nil
    case .healthy: .systemGreen
    case .warning: .systemYellow
    case .critical: .systemRed
    }
  }
}
