import Foundation

public enum PowerSource: String, Codable, Sendable {
  case ac
  case battery
  case unknown
}

public enum ThermalLevel: String, Codable, Sendable {
  case nominal
  case fair
  case serious
  case critical
  case unknown
}

public struct SystemSnapshot: Codable, Equatable, Sendable {
  public let capturedAt: Date
  public let powerSource: PowerSource
  public let batteryPercent: Int?
  public let isCharging: Bool?
  public let timeRemainingSeconds: TimeInterval?
  public let thermalLevel: ThermalLevel
  public let lowPowerModeEnabled: Bool

  public init(
    capturedAt: Date = Date(),
    powerSource: PowerSource,
    batteryPercent: Int?,
    isCharging: Bool?,
    timeRemainingSeconds: TimeInterval?,
    thermalLevel: ThermalLevel,
    lowPowerModeEnabled: Bool
  ) {
    self.capturedAt = capturedAt
    self.powerSource = powerSource
    self.batteryPercent = batteryPercent
    self.isCharging = isCharging
    self.timeRemainingSeconds = timeRemainingSeconds
    self.thermalLevel = thermalLevel
    self.lowPowerModeEnabled = lowPowerModeEnabled
  }
}
