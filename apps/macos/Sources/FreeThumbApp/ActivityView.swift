import Charts
import FreeThumbCore
import SwiftUI

struct ActivityView: View {
  private let controller: AppController
  @ObservedObject private var store: ActivityStore

  init(controller: AppController) {
    self.controller = controller
    store = controller.activityStore
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Toggle(
          "Record activity statistics",
          isOn: Binding(
            get: { store.isEnabled },
            set: { controller.setActivityTrackingEnabled($0) }
          )
        )
        helpText(
          store.isEnabled
            ? "Samples battery, thermal pressure, and the foreground app once per minute."
            : "Recording is off. Existing session data is retained for comparison."
        )

        HStack(spacing: 24) {
          activityMetric("Session", value: formattedDuration(store.tracker.duration))
          activityMetric(
            "Battery used",
            value: localizedFormat(
              "%d percentage points",
              store.tracker.consumedBatteryPercentagePoints
            )
          )
          activityMetric("Samples", value: "\(store.tracker.samples.count)")
        }

        GroupBox("Battery level") {
          if batterySamples.isEmpty {
            emptyChartText("Battery data appears after protection starts.")
          } else {
            Chart(batterySamples) { sample in
              LineMark(
                x: .value("Time", sample.capturedAt),
                y: .value("Battery", sample.batteryPercent ?? 0)
              )
              .foregroundStyle(.green)
            }
            .chartYScale(domain: 0...100)
            .frame(height: 150)
          }
        }

        GroupBox("Thermal pressure") {
          if store.tracker.samples.isEmpty {
            emptyChartText("Thermal data appears after protection starts.")
          } else {
            Chart(store.tracker.samples) { sample in
              LineMark(
                x: .value("Time", sample.capturedAt),
                y: .value("Thermal", sample.thermalLevel.severityRank)
              )
              .interpolationMethod(.stepEnd)
              .foregroundStyle(.orange)
            }
            .chartYScale(domain: 0...4)
            .chartYAxis {
              AxisMarks(values: [1, 2, 3, 4]) { value in
                AxisGridLine()
                AxisValueLabel {
                  if let rank = value.as(Int.self) {
                    Text(thermalLabel(rank))
                  }
                }
              }
            }
            .frame(height: 150)
          }
        }

        GroupBox("Foreground app approximation") {
          VStack(spacing: 8) {
            if store.tracker.appSummaries.isEmpty {
              emptyChartText("App estimates appear after the first one-minute interval.")
            } else {
              ForEach(store.tracker.appSummaries.prefix(8)) { summary in
                VStack(alignment: .leading, spacing: 3) {
                  Text(summary.appName)
                    .lineLimit(1)
                  Text(
                    localizedFormat(
                      "Foreground time: %@ · Battery drop: %d percentage points · Peak thermal pressure: %@",
                      formattedDuration(summary.activeSeconds),
                      summary.batteryPercentagePoints,
                      localized(summary.peakThermalLevel.rawValue.capitalized)
                    )
                  )
                  .foregroundStyle(.secondary)
                }
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
              }
            }
          }
          .frame(maxWidth: .infinity)
        }

        helpText(
          "Samples are recorded once per minute. A battery drop from 80% to 79% is one percentage point. App rows assign each interval to the app that was in front at its start; they do not measure that app's actual energy use. macOS thermal pressure is shown instead of an unsupported CPU temperature estimate."
        )
      }
      .padding(20)
    }
  }

  private func activityMetric(_ title: LocalizedStringKey, value: String) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.headline)
    }
  }

  private func helpText(_ text: String) -> some View {
    Text(LocalizedStringKey(text))
      .font(.caption)
      .foregroundStyle(.secondary)
  }

  private func emptyChartText(_ text: String) -> some View {
    Text(LocalizedStringKey(text))
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, minHeight: 80)
  }

  private func formattedDuration(_ seconds: TimeInterval) -> String {
    let totalMinutes = max(0, Int(seconds)) / 60
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    return hours > 0
      ? localizedFormat("%dh %dm", hours, minutes) : localizedFormat("%dm", minutes)
  }

  private func thermalLabel(_ rank: Int) -> String {
    switch rank {
    case 1: localized("Nominal")
    case 2: localized("Fair")
    case 3: localized("Serious")
    case 4: localized("Critical")
    default: localized("Unknown")
    }
  }

  private var batterySamples: [SessionActivitySample] {
    store.tracker.samples.filter { $0.batteryPercent != nil }
  }
}
