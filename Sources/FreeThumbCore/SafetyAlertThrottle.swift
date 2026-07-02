import Foundation

public struct SafetyAlertThrottle: Sendable {
  public let cooldownSeconds: TimeInterval
  private var lastSentAt: [String: Date] = [:]

  public init(cooldownSeconds: TimeInterval) {
    precondition(cooldownSeconds >= 0)
    self.cooldownSeconds = cooldownSeconds
  }

  public mutating func shouldSend(
    key: String,
    at date: Date = Date(),
    ignoringCooldown: Bool = false
  ) -> Bool {
    if !ignoringCooldown,
      let lastSent = lastSentAt[key],
      date.timeIntervalSince(lastSent) < cooldownSeconds
    {
      return false
    }

    lastSentAt[key] = date
    return true
  }
}
