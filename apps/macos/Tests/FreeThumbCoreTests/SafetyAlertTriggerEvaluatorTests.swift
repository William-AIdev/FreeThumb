import Foundation
import Testing

@testable import FreeThumbCore

struct SafetyAlertTriggerEvaluatorTests {
  @Test func detectsACDisconnect() {
    var evaluator = SafetyAlertTriggerEvaluator()
    let triggers = evaluator.evaluate(
      previous: snapshot(powerSource: .ac),
      current: snapshot(powerSource: .battery),
      remainingSeconds: 3_600,
      configuration: configuration
    )

    #expect(triggers.contains(.powerDisconnected))
  }

  @Test func urgentBatteryTakesPriorityOverWarning() {
    var evaluator = SafetyAlertTriggerEvaluator()
    let triggers = evaluator.evaluate(
      previous: snapshot(powerSource: .battery, batteryPercent: 20),
      current: snapshot(powerSource: .battery, batteryPercent: 20),
      remainingSeconds: 3_600,
      configuration: configuration
    )

    #expect(triggers.contains(.batteryUrgent(percent: 20, threshold: 20)))
    #expect(!triggers.contains(.batteryWarning(percent: 20, threshold: 35)))
  }

  @Test func requiresSustainedThermalPressure() {
    var evaluator = SafetyAlertTriggerEvaluator()
    let start = Date(timeIntervalSince1970: 100)
    let serious = snapshot(thermalLevel: .serious)

    let initial = evaluator.evaluate(
      previous: serious,
      current: serious,
      remainingSeconds: 3_600,
      configuration: configuration,
      at: start
    )
    let sustained = evaluator.evaluate(
      previous: serious,
      current: serious,
      remainingSeconds: 3_600,
      configuration: configuration,
      at: start.addingTimeInterval(30)
    )

    #expect(!initial.contains(.thermalSerious(sustainedSeconds: 30)))
    #expect(sustained.contains(.thermalSerious(sustainedSeconds: 30)))
  }

  @Test func resetsThermalWindowAfterRecovery() {
    var evaluator = SafetyAlertTriggerEvaluator()
    let start = Date(timeIntervalSince1970: 100)
    let serious = snapshot(thermalLevel: .serious)
    let nominal = snapshot(thermalLevel: .nominal)

    _ = evaluator.evaluate(
      previous: serious,
      current: serious,
      remainingSeconds: 3_600,
      configuration: configuration,
      at: start
    )
    _ = evaluator.evaluate(
      previous: serious,
      current: nominal,
      remainingSeconds: 3_600,
      configuration: configuration,
      at: start.addingTimeInterval(20)
    )
    let afterRecovery = evaluator.evaluate(
      previous: nominal,
      current: serious,
      remainingSeconds: 3_600,
      configuration: configuration,
      at: start.addingTimeInterval(31)
    )

    #expect(!afterRecovery.contains(.thermalSerious(sustainedSeconds: 30)))
  }

  @Test func detectsLowPowerModeAndExpiryBoundary() {
    var evaluator = SafetyAlertTriggerEvaluator()
    let lowPower = snapshot(lowPowerModeEnabled: true)
    let triggers = evaluator.evaluate(
      previous: lowPower,
      current: lowPower,
      remainingSeconds: 600,
      configuration: configuration
    )

    #expect(triggers.contains(.lowPowerMode))
    #expect(triggers.contains(.sessionExpiring(remainingSeconds: 600)))
  }

  private var configuration: SafetyAlertEvaluationConfiguration {
    SafetyAlertEvaluationConfiguration(
      batteryWarningPercent: 35,
      batteryUrgentPercent: 20,
      alertOnPowerDisconnect: true,
      alertOnLowPowerMode: true,
      thermalSustainSeconds: 30,
      expiryWarningSeconds: 600
    )
  }

  private func snapshot(
    powerSource: PowerSource = .ac,
    batteryPercent: Int? = 80,
    thermalLevel: ThermalLevel = .nominal,
    lowPowerModeEnabled: Bool = false
  ) -> SystemSnapshot {
    SystemSnapshot(
      capturedAt: Date(timeIntervalSince1970: 0),
      powerSource: powerSource,
      batteryPercent: batteryPercent,
      isCharging: false,
      timeRemainingSeconds: nil,
      thermalLevel: thermalLevel,
      lowPowerModeEnabled: lowPowerModeEnabled
    )
  }
}
