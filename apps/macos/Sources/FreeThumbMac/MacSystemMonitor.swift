import Foundation
import FreeThumbCore
import IOKit.ps

public struct MacSystemMonitor: Sendable {
  public init() {}

  public func snapshot() -> SystemSnapshot {
    let processInfo = ProcessInfo.processInfo
    let battery = batteryDetails()

    return SystemSnapshot(
      powerSource: battery.powerSource,
      batteryPercent: battery.percent,
      isCharging: battery.isCharging,
      timeRemainingSeconds: timeRemaining(),
      thermalLevel: thermalLevel(processInfo.thermalState),
      lowPowerModeEnabled: processInfo.isLowPowerModeEnabled
    )
  }

  private func batteryDetails() -> BatteryDetails {
    let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
    let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]

    for source in sources {
      guard
        let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue()
          as? [String: Any]
      else {
        continue
      }

      let current = description[kIOPSCurrentCapacityKey] as? Int
      let maximum = description[kIOPSMaxCapacityKey] as? Int
      let percent = current.flatMap { current in
        maximum.flatMap { maximum in
          maximum > 0 ? Int((Double(current) / Double(maximum) * 100).rounded()) : nil
        }
      }
      let state = description[kIOPSPowerSourceStateKey] as? String
      let powerSource: PowerSource =
        switch state {
        case kIOPSACPowerValue: .ac
        case kIOPSBatteryPowerValue: .battery
        default: .unknown
        }

      return BatteryDetails(
        powerSource: powerSource,
        percent: percent,
        isCharging: description[kIOPSIsChargingKey] as? Bool
      )
    }

    return BatteryDetails(powerSource: .unknown, percent: nil, isCharging: nil)
  }

  private func timeRemaining() -> TimeInterval? {
    let estimate = IOPSGetTimeRemainingEstimate()
    return estimate >= 0 ? estimate : nil
  }

  private func thermalLevel(_ state: ProcessInfo.ThermalState) -> ThermalLevel {
    switch state {
    case .nominal: .nominal
    case .fair: .fair
    case .serious: .serious
    case .critical: .critical
    @unknown default: .unknown
    }
  }
}

private struct BatteryDetails {
  let powerSource: PowerSource
  let percent: Int?
  let isCharging: Bool?
}
