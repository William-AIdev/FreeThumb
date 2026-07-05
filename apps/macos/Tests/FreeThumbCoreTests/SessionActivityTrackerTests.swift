import Foundation
import Testing

@testable import FreeThumbCore

struct SessionActivityTrackerTests {
  @Test func tracksBatteryDropOnlyWhileDischarging() {
    let start = Date(timeIntervalSince1970: 1_000)
    var tracker = SessionActivityTracker()

    tracker.start(with: sample(at: start, power: .battery, battery: 80, app: "Editor"))
    tracker.record(
      sample(at: start.addingTimeInterval(60), power: .battery, battery: 78, app: "Editor")
    )
    tracker.record(
      sample(at: start.addingTimeInterval(120), power: .ac, battery: 79, app: "Browser")
    )

    #expect(tracker.consumedBatteryPercentagePoints == 2)
    #expect(tracker.appSummaries.first?.batteryPercentagePoints == 2)
  }

  @Test func correlatesElapsedTimeAndThermalPressureWithForegroundApp() {
    let start = Date(timeIntervalSince1970: 2_000)
    var tracker = SessionActivityTracker()

    tracker.start(
      with: sample(at: start, thermal: .fair, app: "Editor")
    )
    tracker.record(
      sample(at: start.addingTimeInterval(30), thermal: .serious, app: "Browser")
    )
    tracker.finish(
      with: sample(at: start.addingTimeInterval(90), thermal: .nominal, app: "Browser")
    )

    #expect(tracker.duration == 90)
    #expect(tracker.appSummaries[0].appName == "Browser")
    #expect(tracker.appSummaries[0].activeSeconds == 60)
    #expect(tracker.appSummaries[0].peakThermalLevel == .serious)
    #expect(tracker.appSummaries[1].activeSeconds == 30)
  }

  @Test func boundsStoredCurveSamples() {
    let start = Date(timeIntervalSince1970: 3_000)
    var tracker = SessionActivityTracker(maximumSamples: 3)
    tracker.start(with: sample(at: start))

    for offset in 1...4 {
      tracker.record(sample(at: start.addingTimeInterval(TimeInterval(offset))))
    }

    #expect(tracker.samples.count == 3)
    #expect(tracker.samples.first?.capturedAt == start.addingTimeInterval(2))
  }

  private func sample(
    at date: Date,
    power: PowerSource = .ac,
    battery: Int? = 100,
    thermal: ThermalLevel = .nominal,
    app: String = "FreeThumb"
  ) -> SessionActivitySample {
    SessionActivitySample(
      capturedAt: date,
      powerSource: power,
      batteryPercent: battery,
      thermalLevel: thermal,
      foregroundApp: app
    )
  }
}
