import Foundation

struct SystemMetricSample: Identifiable, Sendable {
  let id = UUID()
  let capturedAt: Date
  let cpuPercent: Double?
  let memoryUsedBytes: UInt64
  let memoryPercent: Double
  let batteryTemperatureCelsius: Double?
  let systemPowerWatts: Double?
}

struct HighActivityApp: Identifiable, Sendable {
  var id: Int32 { processID }
  let processID: Int32
  let name: String
  let energyImpact: Double
  let cpuPercent: Double
  let memoryBytes: UInt64
}

@MainActor
final class SystemMetricsStore: ObservableObject {
  @Published private(set) var samples: [SystemMetricSample] = []
  @Published private(set) var highActivityApps: [HighActivityApp] = []

  func replaceSamples(_ samples: [SystemMetricSample]) {
    self.samples = samples
  }

  func replaceHighActivityApps(_ apps: [HighActivityApp]) {
    highActivityApps = apps
  }
}
