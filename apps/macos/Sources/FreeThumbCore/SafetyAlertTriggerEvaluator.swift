import Foundation

public enum SafetyAlertTrigger: Equatable, Sendable {
  case powerDisconnected
  case batteryWarning(percent: Int, threshold: Int)
  case batteryUrgent(percent: Int, threshold: Int)
  case thermalSerious(sustainedSeconds: Int)
  case thermalCritical(sustainedSeconds: Int)
  case lowPowerMode
  case sessionExpiring(remainingSeconds: Int)
}

public struct SafetyAlertEvaluationConfiguration: Equatable, Sendable {
  public let batteryWarningPercent: Int
  public let batteryUrgentPercent: Int
  public let alertOnPowerDisconnect: Bool
  public let alertOnLowPowerMode: Bool
  public let thermalSustainSeconds: Int
  public let expiryWarningSeconds: Int

  public init(
    batteryWarningPercent: Int,
    batteryUrgentPercent: Int,
    alertOnPowerDisconnect: Bool,
    alertOnLowPowerMode: Bool,
    thermalSustainSeconds: Int,
    expiryWarningSeconds: Int
  ) {
    precondition((0...100).contains(batteryUrgentPercent))
    precondition((batteryUrgentPercent...100).contains(batteryWarningPercent))
    precondition(thermalSustainSeconds >= 0)
    precondition(expiryWarningSeconds >= 0)
    self.batteryWarningPercent = batteryWarningPercent
    self.batteryUrgentPercent = batteryUrgentPercent
    self.alertOnPowerDisconnect = alertOnPowerDisconnect
    self.alertOnLowPowerMode = alertOnLowPowerMode
    self.thermalSustainSeconds = thermalSustainSeconds
    self.expiryWarningSeconds = expiryWarningSeconds
  }
}

public struct SafetyAlertTriggerEvaluator: Sendable {
  private var thermalRiskStartedAt: Date?

  public init() {}

  public mutating func evaluate(
    previous: SystemSnapshot,
    current: SystemSnapshot,
    remainingSeconds: Int,
    configuration: SafetyAlertEvaluationConfiguration,
    at date: Date = Date()
  ) -> [SafetyAlertTrigger] {
    var triggers: [SafetyAlertTrigger] = []

    if configuration.alertOnPowerDisconnect,
      previous.powerSource == .ac,
      current.powerSource == .battery
    {
      triggers.append(.powerDisconnected)
    }

    if current.powerSource == .battery, let batteryPercent = current.batteryPercent {
      if batteryPercent <= configuration.batteryUrgentPercent {
        triggers.append(
          .batteryUrgent(
            percent: batteryPercent,
            threshold: configuration.batteryUrgentPercent
          )
        )
      } else if batteryPercent <= configuration.batteryWarningPercent {
        triggers.append(
          .batteryWarning(
            percent: batteryPercent,
            threshold: configuration.batteryWarningPercent
          )
        )
      }
    }

    evaluateThermal(
      current: current,
      configuration: configuration,
      at: date,
      triggers: &triggers
    )

    if configuration.alertOnLowPowerMode && current.lowPowerModeEnabled {
      triggers.append(.lowPowerMode)
    }

    if remainingSeconds <= configuration.expiryWarningSeconds {
      triggers.append(.sessionExpiring(remainingSeconds: max(0, remainingSeconds)))
    }

    return triggers
  }

  private mutating func evaluateThermal(
    current: SystemSnapshot,
    configuration: SafetyAlertEvaluationConfiguration,
    at date: Date,
    triggers: inout [SafetyAlertTrigger]
  ) {
    switch current.thermalLevel {
    case .critical, .serious:
      if thermalRiskStartedAt == nil {
        thermalRiskStartedAt = date
      }
      guard let startedAt = thermalRiskStartedAt,
        date.timeIntervalSince(startedAt) >= TimeInterval(configuration.thermalSustainSeconds)
      else { return }

      if current.thermalLevel == .critical {
        triggers.append(
          .thermalCritical(sustainedSeconds: configuration.thermalSustainSeconds)
        )
      } else {
        triggers.append(
          .thermalSerious(sustainedSeconds: configuration.thermalSustainSeconds)
        )
      }
    case .nominal, .fair, .unknown:
      thermalRiskStartedAt = nil
    }
  }
}
