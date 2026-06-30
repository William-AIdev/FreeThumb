import AppKit
import SwiftUI

@main
struct FreeThumbApp: App {
  @StateObject private var controller = AppController()

  var body: some Scene {
    MenuBarExtra {
      MenuBarContentView(controller: controller)
    } label: {
      Label("FreeThumb", systemImage: controller.menuBarIconName)
    }
    .menuBarExtraStyle(.window)
  }
}
