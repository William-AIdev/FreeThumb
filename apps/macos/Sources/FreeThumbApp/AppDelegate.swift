import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationWillFinishLaunching(_ notification: Notification) {
    NotificationService.configurePresentation()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    NotificationService.logCurrentSettings()
  }
}
