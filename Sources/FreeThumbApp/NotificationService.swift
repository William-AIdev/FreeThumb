import Foundation
import UserNotifications

struct NotificationService: Sendable {
  func prepare() async {
    let center = UNUserNotificationCenter.current()
    let settings = await center.notificationSettings()
    if settings.authorizationStatus == .notDetermined {
      _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }
  }

  func send(title: String, body: String) async throws {
    let center = UNUserNotificationCenter.current()
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: nil
    )
    try await center.add(request)
  }
}
