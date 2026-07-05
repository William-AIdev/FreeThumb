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

  @Test func supportsFullBatteryThresholdRange() {
    let fullRangePolicy = ProtectionPolicy(
      batteryWarningPercent: 100,
      batteryUrgentPercent: 100
    )
    let snapshot = makeSnapshot(powerSource: .battery, batteryPercent: 80)
    #expect(
      fullRangePolicy.evaluate(snapshot)
        == .warn(reason: "Battery is critically low at or below 100%")
    )
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

struct SafetyAlertThrottleTests {
  @Test func suppressesRepeatedAlertsDuringCooldown() {
    var throttle = SafetyAlertThrottle(cooldownSeconds: 60)
    let start = Date(timeIntervalSince1970: 100)

    let first = throttle.shouldSend(key: "battery", at: start)
    let suppressed = throttle.shouldSend(key: "battery", at: start.addingTimeInterval(59))
    let afterCooldown = throttle.shouldSend(
      key: "battery",
      at: start.addingTimeInterval(60)
    )

    #expect(first)
    #expect(!suppressed)
    #expect(afterCooldown)
  }

  @Test func tracksAlertKindsIndependently() {
    var throttle = SafetyAlertThrottle(cooldownSeconds: 60)
    let now = Date(timeIntervalSince1970: 100)

    let battery = throttle.shouldSend(key: "battery", at: now)
    let thermal = throttle.shouldSend(key: "thermal", at: now)

    #expect(battery)
    #expect(thermal)
  }

  @Test func canBypassCooldownForRestoreFailure() {
    var throttle = SafetyAlertThrottle(cooldownSeconds: 60)
    let now = Date(timeIntervalSince1970: 100)

    let first = throttle.shouldSend(key: "restore", at: now)
    let bypassed = throttle.shouldSend(
      key: "restore",
      at: now.addingTimeInterval(1),
      ignoringCooldown: true
    )

    #expect(first)
    #expect(bypassed)
  }
}
