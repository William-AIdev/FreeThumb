import Foundation
import UserNotifications
import os

struct NotificationService: Sendable {
  private static let logger = Logger(subsystem: "com.freethumb.app", category: "notifications")

  @MainActor
  static func configurePresentation() {
    UNUserNotificationCenter.current().delegate = NotificationPresentationDelegate.shared
  }

  static func logCurrentSettings() {
    Task {
      let summary = await authorizationSummary()
      logger.info("Local notification settings: \(summary, privacy: .public)")
    }
  }

  static func authorizationSummary() async -> String {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    let authorization =
      switch settings.authorizationStatus {
      case .notDetermined: "not requested"
      case .denied: "denied"
      case .authorized: "authorized"
      case .provisional: "provisional"
      case .ephemeral: "ephemeral"
      @unknown default: "unknown"
      }
    return
      "\(authorization); alerts=\(settingDescription(settings.alertSetting)); "
      + "notificationCenter=\(settingDescription(settings.notificationCenterSetting)); "
      + "sound=\(settingDescription(settings.soundSetting))"
  }

  func prepare() async throws {
    let center = UNUserNotificationCenter.current()
    await Self.configurePresentation()
    let settings = await center.notificationSettings()
    if settings.authorizationStatus == .notDetermined {
      let granted = try await center.requestAuthorization(options: [.alert, .sound])
      guard granted else { throw NotificationServiceError.authorizationDenied }
    } else if settings.authorizationStatus == .denied {
      throw NotificationServiceError.authorizationDenied
    }
  }

  func send(title: String, body: String) async throws {
    try await prepare()
    let center = UNUserNotificationCenter.current()
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    )
    try await center.add(request)
  }

  private static func settingDescription(_ setting: UNNotificationSetting) -> String {
    switch setting {
    case .notSupported: "not supported"
    case .disabled: "disabled"
    case .enabled: "enabled"
    @unknown default: "unknown"
    }
  }
}

private final class NotificationPresentationDelegate: NSObject,
  UNUserNotificationCenterDelegate, @unchecked Sendable
{
  static let shared = NotificationPresentationDelegate()

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }
}

private enum NotificationServiceError: LocalizedError {
  case authorizationDenied

  var errorDescription: String? {
    "Notifications are disabled. Enable FreeThumb in System Settings > Notifications."
  }
}
