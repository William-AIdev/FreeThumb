import Foundation

struct SafetyAlertConfiguration: Equatable, Sendable {
  var localNotificationsEnabled = true
  var iMessageEnabled = false
  var iMessageRecipient = ""
  var emailEnabled = false
  var emailRecipient = ""
  var webhookEnabled = false
  var webhookURL = ""
  var alertOnPowerDisconnect = true
  var alertOnLowPowerMode = true
  var thermalSustainSeconds = 30
  var expiryWarningMinutes = 10
  var cooldownMinutes = 15

  var hasEnabledChannel: Bool {
    localNotificationsEnabled || iMessageEnabled || emailEnabled || webhookEnabled
  }
}

struct SafetyAlertMessage: Sendable {
  let title: String
  let body: String
}

actor SafetyAlertDelivery {
  private let localNotifications = NotificationService()

  func prepare(configuration: SafetyAlertConfiguration) async {
    if configuration.localNotificationsEnabled {
      await localNotifications.prepare()
    }
  }

  func send(
    _ message: SafetyAlertMessage,
    configuration: SafetyAlertConfiguration
  ) async -> [String] {
    var failures: [String] = []

    if configuration.localNotificationsEnabled {
      do {
        try await localNotifications.send(title: message.title, body: message.body)
      } catch {
        failures.append("local notification: \(error.localizedDescription)")
      }
    }

    if configuration.iMessageEnabled {
      do {
        try sendIMessage(message, recipient: configuration.iMessageRecipient)
      } catch {
        failures.append("iMessage: \(error.localizedDescription)")
      }
    }

    if configuration.emailEnabled {
      do {
        try sendEmail(message, recipient: configuration.emailRecipient)
      } catch {
        failures.append("email: \(error.localizedDescription)")
      }
    }

    if configuration.webhookEnabled {
      do {
        try await sendWebhook(message, urlString: configuration.webhookURL)
      } catch {
        failures.append("webhook: \(error.localizedDescription)")
      }
    }

    return failures
  }

  private func sendIMessage(_ message: SafetyAlertMessage, recipient: String) throws {
    let recipient = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !recipient.isEmpty else {
      throw SafetyAlertDeliveryError.missingIMessageRecipient
    }

    let script = """
      on run argv
        set targetHandle to item 1 of argv
        set messageText to item 2 of argv
        tell application "Messages"
          set targetAccount to first account whose service type is iMessage and enabled is true
          set targetParticipant to participant targetHandle of targetAccount
          send messageText to targetParticipant
        end tell
      end run
      """
    try runAppleScript(script, arguments: [recipient, formattedBody(message)])
  }

  private func sendEmail(_ message: SafetyAlertMessage, recipient: String) throws {
    let recipient = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
    guard recipient.contains("@") else {
      throw SafetyAlertDeliveryError.invalidEmailRecipient
    }

    let script = """
      on run argv
        set targetAddress to item 1 of argv
        set messageSubject to item 2 of argv
        set messageBody to item 3 of argv
        tell application "Mail"
          set outgoingMessage to make new outgoing message with properties {subject:messageSubject, content:messageBody & return, visible:false}
          tell outgoingMessage
            make new to recipient at end of to recipients with properties {address:targetAddress}
            send
          end tell
        end tell
      end run
      """
    try runAppleScript(script, arguments: [recipient, message.title, message.body])
  }

  private func sendWebhook(_ message: SafetyAlertMessage, urlString: String) async throws {
    guard
      let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
      url.scheme?.lowercased() == "https",
      url.host != nil
    else {
      throw SafetyAlertDeliveryError.invalidWebhookURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 10
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "source": "FreeThumb",
      "title": message.title,
      "body": message.body,
      "sentAt": ISO8601DateFormatter().string(from: Date()),
    ])

    let (_, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse,
      (200..<300).contains(httpResponse.statusCode)
    else {
      throw SafetyAlertDeliveryError.webhookRejected
    }
  }

  private func runAppleScript(_ source: String, arguments: [String]) throws {
    let process = Process()
    let standardError = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", source, "--"] + arguments
    process.standardOutput = FileHandle.nullDevice
    process.standardError = standardError
    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
      let details = String(
        decoding: standardError.fileHandleForReading.readDataToEndOfFile(),
        as: UTF8.self
      ).trimmingCharacters(in: .whitespacesAndNewlines)
      throw SafetyAlertDeliveryError.appleScriptFailed(
        details.isEmpty ? "osascript exited with status \(process.terminationStatus)" : details
      )
    }
  }

  private func formattedBody(_ message: SafetyAlertMessage) -> String {
    "\(message.title)\n\(message.body)"
  }
}

private enum SafetyAlertDeliveryError: LocalizedError {
  case missingIMessageRecipient
  case invalidEmailRecipient
  case invalidWebhookURL
  case webhookRejected
  case appleScriptFailed(String)

  var errorDescription: String? {
    switch self {
    case .missingIMessageRecipient:
      "No iMessage recipient is configured"
    case .invalidEmailRecipient:
      "The email recipient is invalid"
    case .invalidWebhookURL:
      "The webhook must be a valid HTTPS URL"
    case .webhookRejected:
      "The webhook returned a non-success response"
    case .appleScriptFailed(let details):
      details
    }
  }
}
