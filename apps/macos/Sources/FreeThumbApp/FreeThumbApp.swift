import AppKit
import SwiftUI

@main
struct FreeThumbApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var controller = AppController()
  @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue

  var body: some Scene {
    MenuBarExtra {
      MenuBarContentView(controller: controller)
        .environment(\.locale, selectedLanguage.locale)
    } label: {
      Image(nsImage: controller.statusIconImage(pointSize: 16))
        .accessibilityLabel(controller.menuBarAccessibilityLabel)
    }
    .menuBarExtraStyle(.window)

    Settings {
      SettingsView(controller: controller)
        .environment(\.locale, selectedLanguage.locale)
    }
  }

  private var selectedLanguage: AppLanguage {
    AppLanguage(rawValue: appLanguage) ?? .system
  }
}
