import Darwin
import Foundation
import IOKit

public struct PerformanceMetricSnapshot: Sendable {
  public let capturedAt: Date
  public let cpuPercent: Double?
  public let memoryUsedBytes: UInt64
  public let memoryPercent: Double
  public let batteryTemperatureCelsius: Double?
  public let systemPowerWatts: Double?
}

public final class PerformanceMetricsMonitor {
  private var previousCPUTicks: CPUTicks?

  public init() {
    previousCPUTicks = Self.readCPUTicks()
  }

  public func snapshot() -> PerformanceMetricSnapshot {
    let cpuPercent = currentCPUPercent()
    let memory = Self.readMemoryUsage()
    let power = Self.readPowerMetrics()
    return PerformanceMetricSnapshot(
      capturedAt: Date(),
      cpuPercent: cpuPercent,
      memoryUsedBytes: memory.usedBytes,
      memoryPercent: memory.percent,
      batteryTemperatureCelsius: power.temperatureCelsius,
      systemPowerWatts: power.totalPowerWatts
    )
  }

  private func currentCPUPercent() -> Double? {
    guard let current = Self.readCPUTicks() else { return nil }
    defer { previousCPUTicks = current }
    guard let previousCPUTicks else { return nil }

    let busy = current.busy >= previousCPUTicks.busy ? current.busy - previousCPUTicks.busy : 0
    let total = current.total >= previousCPUTicks.total ? current.total - previousCPUTicks.total : 0
    guard total > 0 else { return nil }
    return min(100, max(0, Double(busy) / Double(total) * 100))
  }

  private static func readCPUTicks() -> CPUTicks? {
    var load = host_cpu_load_info_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
    )
    let result = withUnsafeMutablePointer(to: &load) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
      }
    }
    guard result == KERN_SUCCESS else { return nil }

    let user = UInt64(load.cpu_ticks.0)
    let system = UInt64(load.cpu_ticks.1)
    let idle = UInt64(load.cpu_ticks.2)
    let nice = UInt64(load.cpu_ticks.3)
    return CPUTicks(busy: user + system + nice, total: user + system + idle + nice)
  }

  private static func readMemoryUsage() -> (usedBytes: UInt64, percent: Double) {
    var statistics = vm_statistics64()
    var count = mach_msg_type_number_t(
      MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
    )
    let result = withUnsafeMutablePointer(to: &statistics) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
      }
    }
    guard result == KERN_SUCCESS else { return (0, 0) }

    var pageSizeValue: vm_size_t = 0
    guard host_page_size(mach_host_self(), &pageSizeValue) == KERN_SUCCESS else { return (0, 0) }
    let pageSize = UInt64(pageSizeValue)
    let pages =
      UInt64(statistics.active_count) + UInt64(statistics.inactive_count)
      + UInt64(statistics.wire_count) + UInt64(statistics.compressor_page_count)
    let total = ProcessInfo.processInfo.physicalMemory
    let used = min(total, pages * pageSize)
    let percent = total > 0 ? Double(used) / Double(total) * 100 : 0
    return (used, percent)
  }

  private static func readPowerMetrics() -> (
    temperatureCelsius: Double?, totalPowerWatts: Double?
  ) {
    let service = IOServiceGetMatchingService(
      kIOMainPortDefault,
      IOServiceMatching("AppleSmartBattery")
    )
    guard service != IO_OBJECT_NULL else { return (nil, nil) }
    defer { IOObjectRelease(service) }

    var properties: Unmanaged<CFMutableDictionary>?
    guard
      IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0)
        == KERN_SUCCESS,
      let values = properties?.takeRetainedValue() as? [String: Any]
    else { return (nil, nil) }

    let temperature = (values["Temperature"] as? NSNumber).flatMap {
      normalizedBatteryTemperature($0.doubleValue)
    }
    let isExternallyPowered = (values["ExternalConnected"] as? NSNumber)?.boolValue ?? false
    let telemetry = values["PowerTelemetryData"] as? [String: Any]
    let telemetryKeys =
      isExternallyPowered
      ? ["SystemPowerIn", "WallEnergyEstimate", "SystemLoad"]
      : ["SystemLoad", "BatteryPower"]
    for key in telemetryKeys {
      guard let number = telemetry?[key] as? NSNumber else { continue }
      let milliwatts = abs(number.int64Value)
      if milliwatts > 0, milliwatts < 500_000 {
        return (temperature, Double(milliwatts) / 1_000)
      }
    }

    guard !isExternallyPowered,
      let voltageMillivolts = (values["Voltage"] as? NSNumber)?.doubleValue,
      let currentMilliamps = (values["InstantAmperage"] as? NSNumber)?.int64Value
    else { return (temperature, nil) }

    let watts = abs(Double(currentMilliamps) * voltageMillivolts) / 1_000_000
    return (temperature, watts.isFinite ? watts : nil)
  }

  private static func normalizedBatteryTemperature(_ rawValue: Double) -> Double? {
    let celsius = rawValue > 200 ? rawValue / 100 : rawValue
    return (0...100).contains(celsius) ? celsius : nil
  }
}

private struct CPUTicks {
  let busy: UInt64
  let total: UInt64
}
