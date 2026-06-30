import Foundation
import Testing

@testable import FreeThumbCore

struct ProtectionPolicyTests {
  private let policy = ProtectionPolicy()

  @Test func continuesOnHealthyACPower() {
    let snapshot = makeSnapshot(powerSource: .ac, batteryPercent: 10)
    #expect(policy.evaluate(snapshot) == .continueRunning)
  }

  @Test func continuesOnHealthyBatteryPower() {
    let snapshot = makeSnapshot(powerSource: .battery, batteryPercent: 80)
    #expect(policy.evaluate(snapshot) == .continueRunning)
  }

  @Test func warnsAtCriticalTemperatureWithoutStopping() {
    let snapshot = makeSnapshot(thermalLevel: .critical)
    #expect(policy.evaluate(snapshot) == .warn(reason: "System thermal state is critical"))
  }

  @Test func warnsAtUrgentBatteryLevelWithoutStopping() {
    let snapshot = makeSnapshot(powerSource: .battery, batteryPercent: 20)
    #expect(
      policy.evaluate(snapshot)
        == .warn(reason: "Battery is critically low at or below 20%")
    )
  }

  @Test func warnsAtLowBatteryLevel() {
    let snapshot = makeSnapshot(powerSource: .battery, batteryPercent: 35)
    #expect(policy.evaluate(snapshot) == .warn(reason: "Battery is at or below 35%"))
  }

  @Test func warnsWhenTemperatureIsSerious() {
    let snapshot = makeSnapshot(thermalLevel: .serious)
    #expect(policy.evaluate(snapshot) == .warn(reason: "System thermal state is serious"))
  }

  @Test func criticalThermalWarningTakesPriority() {
    let snapshot = makeSnapshot(
      powerSource: .battery,
      batteryPercent: 10,
      thermalLevel: .critical
    )
    #expect(policy.evaluate(snapshot) == .warn(reason: "System thermal state is critical"))
  }

  private func makeSnapshot(
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
