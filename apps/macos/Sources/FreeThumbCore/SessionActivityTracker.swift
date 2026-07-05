import Foundation

public struct SessionActivitySample: Identifiable, Equatable, Sendable {
  public let id: UUID
  public let capturedAt: Date
  public let powerSource: PowerSource
  public let batteryPercent: Int?
  public let thermalLevel: ThermalLevel
  public let foregroundApp: String

  public init(
    id: UUID = UUID(),
    capturedAt: Date,
    powerSource: PowerSource,
    batteryPercent: Int?,
    thermalLevel: ThermalLevel,
    foregroundApp: String
  ) {
    self.id = id
    self.capturedAt = capturedAt
    self.powerSource = powerSource
    self.batteryPercent = batteryPercent
    self.thermalLevel = thermalLevel
    self.foregroundApp = foregroundApp
  }
}

public struct AppActivitySummary: Identifiable, Equatable, Sendable {
  public var id: String { appName }
  public let appName: String
  public let activeSeconds: TimeInterval
  public let batteryPercentagePoints: Int
  public let peakThermalLevel: ThermalLevel
}

public struct SessionActivityTracker: Sendable {
  public private(set) var samples: [SessionActivitySample] = []
  public private(set) var startedAt: Date?
  public private(set) var endedAt: Date?
  public private(set) var consumedBatteryPercentagePoints = 0

  private let maximumSamples: Int
  private var appStatistics: [String: AppAccumulator] = [:]

  public init(maximumSamples: Int = 1_440) {
    precondition(maximumSamples > 1)
    self.maximumSamples = maximumSamples
  }

  public mutating func start(with sample: SessionActivitySample) {
    samples = [sample]
    startedAt = sample.capturedAt
    endedAt = nil
    consumedBatteryPercentagePoints = 0
    appStatistics = [:]
  }

  public mutating func record(_ sample: SessionActivitySample) {
    guard let previous = samples.last else {
      start(with: sample)
      return
    }

    let elapsed = max(0, sample.capturedAt.timeIntervalSince(previous.capturedAt))
    var accumulator = appStatistics[previous.foregroundApp] ?? AppAccumulator()
    accumulator.activeSeconds += elapsed
    accumulator.peakThermalLevel = maxThermal(
      accumulator.peakThermalLevel,
      previous.thermalLevel
    )

    if previous.powerSource == .battery,
      sample.powerSource == .battery,
      let previousPercent = previous.batteryPercent,
      let currentPercent = sample.batteryPercent,
      currentPercent < previousPercent
    {
      let drop = previousPercent - currentPercent
      consumedBatteryPercentagePoints += drop
      accumulator.batteryPercentagePoints += drop
    }
    appStatistics[previous.foregroundApp] = accumulator

    samples.append(sample)
    if samples.count > maximumSamples {
      samples.removeFirst(samples.count - maximumSamples)
    }
  }

  public mutating func finish(with sample: SessionActivitySample) {
    record(sample)
    endedAt = sample.capturedAt
  }

  public var duration: TimeInterval {
    guard let startedAt else { return 0 }
    return max(0, (endedAt ?? samples.last?.capturedAt ?? startedAt).timeIntervalSince(startedAt))
  }

  public var appSummaries: [AppActivitySummary] {
    appStatistics.map { appName, value in
      AppActivitySummary(
        appName: appName,
        activeSeconds: value.activeSeconds,
        batteryPercentagePoints: value.batteryPercentagePoints,
        peakThermalLevel: value.peakThermalLevel
      )
    }
    .sorted {
      if $0.activeSeconds == $1.activeSeconds { return $0.appName < $1.appName }
      return $0.activeSeconds > $1.activeSeconds
    }
  }

  private func maxThermal(_ left: ThermalLevel, _ right: ThermalLevel) -> ThermalLevel {
    left.severityRank >= right.severityRank ? left : right
  }
}

extension ThermalLevel {
  public var severityRank: Int {
    switch self {
    case .unknown: 0
    case .nominal: 1
    case .fair: 2
    case .serious: 3
    case .critical: 4
    }
  }
}

private struct AppAccumulator: Sendable {
  var activeSeconds: TimeInterval = 0
  var batteryPercentagePoints = 0
  var peakThermalLevel: ThermalLevel = .unknown
}
