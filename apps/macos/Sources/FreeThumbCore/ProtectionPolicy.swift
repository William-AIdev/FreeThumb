public struct ProtectionPolicy: Equatable, Sendable {
  public let batteryWarningPercent: Int
  public let batteryUrgentPercent: Int

  public init(batteryWarningPercent: Int = 35, batteryUrgentPercent: Int = 20) {
    precondition((0...100).contains(batteryUrgentPercent))
    precondition((batteryUrgentPercent...100).contains(batteryWarningPercent))
    self.batteryWarningPercent = batteryWarningPercent
    self.batteryUrgentPercent = batteryUrgentPercent
  }

  public func evaluate(_ snapshot: SystemSnapshot) -> ProtectionDecision {
    if snapshot.thermalLevel == .critical {
      return .warn(reason: "System thermal state is critical")
    }

    if snapshot.powerSource == .battery,
      let batteryPercent = snapshot.batteryPercent,
      batteryPercent <= batteryUrgentPercent
    {
      return .warn(reason: "Battery is critically low at or below \(batteryUrgentPercent)%")
    }

    if snapshot.thermalLevel == .serious {
      return .warn(reason: "System thermal state is serious")
    }

    if snapshot.powerSource == .battery,
      let batteryPercent = snapshot.batteryPercent,
      batteryPercent <= batteryWarningPercent
    {
      return .warn(reason: "Battery is at or below \(batteryWarningPercent)%")
    }

    if snapshot.powerSource == .battery && snapshot.lowPowerModeEnabled {
      return .warn(reason: "Low Power Mode is enabled")
    }

    return .continueRunning
  }
}

public enum ProtectionDecision: Equatable, Sendable {
  case continueRunning
  case warn(reason: String)
}
