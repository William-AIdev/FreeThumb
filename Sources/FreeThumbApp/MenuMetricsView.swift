import Charts
import SwiftUI

struct MenuMetricsView: View {
  @ObservedObject var store: SystemMetricsStore
  let showSystemPressure: Bool
  let showBatteryMetrics: Bool
  let showHighActivityApps: Bool
  @State private var hoveredMetric: MetricKind?
  @State private var selectedSample: SystemMetricSample?

  var body: some View {
    VStack(spacing: 14) {
      if showSystemPressure {
        metricCard(
          "System pressure",
          currentValue: pressureValue,
          metrics: [.pressure]
        ) {
          Chart(chartSamples) { sample in
            if let cpuPercent = sample.cpuPercent {
              LineMark(
                x: .value("Time", sample.capturedAt),
                y: .value("Percent", cpuPercent)
              )
              .foregroundStyle(by: .value("Metric", "CPU"))
            }
            LineMark(
              x: .value("Time", sample.capturedAt),
              y: .value("Percent", sample.memoryPercent)
            )
            .foregroundStyle(by: .value("Metric", "Memory"))

            if hoveredMetric == .pressure,
              selectedSample?.id == sample.id
            {
              RuleMark(x: .value("Selected time", sample.capturedAt))
                .foregroundStyle(.secondary)
              if let cpuPercent = sample.cpuPercent {
                PointMark(
                  x: .value("Time", sample.capturedAt),
                  y: .value("CPU", cpuPercent)
                )
                .foregroundStyle(.blue)
              }
              PointMark(
                x: .value("Time", sample.capturedAt),
                y: .value("Memory", sample.memoryPercent)
              )
              .foregroundStyle(.cyan)
            }
          }
          .chartYScale(domain: 0...100)
          .chartXAxis {
            AxisMarks(preset: .aligned, values: .automatic(desiredCount: 3)) { value in
              AxisGridLine()
              AxisTick()
              AxisValueLabel {
                if let date = value.as(Date.self) {
                  Text(date, format: .dateTime.hour().minute())
                }
              }
            }
          }
          .chartYAxis {
            AxisMarks { value in
              AxisGridLine()
              AxisTick()
              AxisValueLabel {
                if let percent = value.as(Double.self) {
                  Text(String(format: "%.0f%%", percent))
                }
              }
            }
          }
          .chartLegend(position: .bottom, spacing: 8)
          .chartOverlay { proxy in
            GeometryReader { geometry in
              hoverOverlay(
                proxy: proxy,
                geometry: geometry,
                metric: .pressure,
                samples: chartSamples
              )
            }
          }
          .overlay(alignment: .topTrailing) {
            if hoveredMetric == .pressure, let selectedSample {
              pressureTooltip(selectedSample)
                .padding(.top, 4)
                .padding(.trailing, 4)
            }
          }
        }
      }

      if showBatteryMetrics {
        metricCard(
          "Battery temperature & total power",
          currentValue: batteryMetricsValue,
          metrics: [.battery],
          chartHeight: 165
        ) {
          VStack(spacing: 4) {
            HStack(spacing: 12) {
              metricLegend(color: .blue, title: "Battery temperature")
              metricLegend(color: .purple, title: "Total power draw")
            }
            .font(.caption2)
            batteryChart
          }
        }
      }

      if showHighActivityApps {
        VStack(alignment: .leading, spacing: 8) {
          Text("High energy apps (estimated)")
            .font(.subheadline.weight(.semibold))
          if store.highActivityApps.isEmpty {
            Text("No third-party app is currently using notable energy.")
              .font(.caption)
              .foregroundStyle(.secondary)
          } else {
            ForEach(store.highActivityApps) { app in
              HStack {
                Text(app.name)
                  .lineLimit(1)
                Spacer()
                Text(String(format: "%.1f", app.energyImpact))
                  .monospacedDigit()
                Text(formattedBytes(app.memoryBytes))
                  .foregroundStyle(.secondary)
              }
              .font(.caption)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  private func metricCard<Content: View>(
    _ title: LocalizedStringKey,
    currentValue: String,
    metrics: Set<MetricKind>,
    chartHeight: CGFloat = 110,
    @ViewBuilder chart: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(title)
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.75)
          .layoutPriority(1)
        Spacer()
        Text(currentValue)
          .font(.subheadline.monospacedDigit().weight(.semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      chart()
        .frame(height: chartHeight)
    }
    .padding(10)
    .background(.primary.opacity(0.045))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay {
      RoundedRectangle(cornerRadius: 10)
        .stroke(.secondary.opacity(0.28), lineWidth: 1)
    }
    .zIndex(hoveredMetric.map(metrics.contains) == true ? 1 : 0)
  }

  private var latest: SystemMetricSample? { store.samples.last }

  private var pressureValue: String {
    guard let latest else { return localized("Waiting for sample") }
    let memory = formattedBytes(latest.memoryUsedBytes)
    let cpu = latest.cpuPercent.map { String(format: "%.1f%%", $0) } ?? "—"
    return "\(memory) · CPU \(cpu)"
  }

  private var temperatureValue: String {
    latest?.batteryTemperatureCelsius.map { String(format: "%.1f°C", $0) }
      ?? localized("Unavailable")
  }

  private var powerValue: String {
    latest?.systemPowerWatts.map { String(format: "%.2f W", $0) }
      ?? localized("Unavailable")
  }

  private var batteryMetricsValue: String {
    "\(temperatureValue) · \(powerValue)"
  }

  private var batteryChart: some View {
    Chart {
      ForEach(chartSamples) { sample in
        if let temperature = sample.batteryTemperatureCelsius {
          LineMark(
            x: .value("Time", sample.capturedAt),
            y: .value("Temperature", normalized(temperature, in: temperatureDomain)),
            series: .value("Metric", "Temperature")
          )
          .foregroundStyle(.blue)
        }
        if let power = sample.systemPowerWatts {
          LineMark(
            x: .value("Time", sample.capturedAt),
            y: .value("Power", normalized(power, in: powerDomain)),
            series: .value("Metric", "Power")
          )
          .foregroundStyle(.purple)
        }

        if hoveredMetric == .battery, selectedSample?.id == sample.id {
          RuleMark(x: .value("Selected time", sample.capturedAt))
            .foregroundStyle(.secondary)
          if let temperature = sample.batteryTemperatureCelsius {
            PointMark(
              x: .value("Time", sample.capturedAt),
              y: .value("Temperature", normalized(temperature, in: temperatureDomain))
            )
            .foregroundStyle(.blue)
          }
          if let power = sample.systemPowerWatts {
            PointMark(
              x: .value("Time", sample.capturedAt),
              y: .value("Power", normalized(power, in: powerDomain))
            )
            .foregroundStyle(.purple)
          }
        }
      }
    }
    .chartYScale(domain: 0...1)
    .chartXAxis {
      AxisMarks(preset: .aligned, values: .automatic(desiredCount: 3)) { value in
        AxisGridLine()
        AxisTick()
        AxisValueLabel {
          if let date = value.as(Date.self) {
            Text(date, format: .dateTime.hour().minute())
          }
        }
      }
    }
    .chartYAxis {
      AxisMarks(position: .leading, values: [0.0, 0.5, 1.0]) { value in
        AxisGridLine()
        AxisTick()
        AxisValueLabel {
          if let normalizedValue = value.as(Double.self) {
            Text(String(format: "%.0f°C", denormalized(normalizedValue, in: temperatureDomain)))
              .foregroundStyle(.blue)
          }
        }
      }
      AxisMarks(position: .trailing, values: [0.0, 0.5, 1.0]) { value in
        AxisTick()
        AxisValueLabel {
          if let normalizedValue = value.as(Double.self) {
            Text(String(format: "%.1f W", denormalized(normalizedValue, in: powerDomain)))
              .foregroundStyle(.purple)
          }
        }
      }
    }
    .chartOverlay { proxy in
      GeometryReader { geometry in
        hoverOverlay(proxy: proxy, geometry: geometry, metric: .battery, samples: chartSamples)
      }
    }
    .overlay(alignment: .topTrailing) {
      if hoveredMetric == .battery, let selectedSample {
        batteryTooltip(selectedSample)
          .padding(.top, 4)
          .padding(.trailing, 42)
      }
    }
  }

  private func metricLegend(color: Color, title: LocalizedStringKey) -> some View {
    HStack(spacing: 4) {
      Circle()
        .fill(color)
        .frame(width: 6, height: 6)
      Text(title)
    }
  }

  private var temperatureDomain: ClosedRange<Double> {
    paddedDomain(
      store.samples.compactMap(\.batteryTemperatureCelsius),
      fallback: 20...40
    )
  }

  private var powerDomain: ClosedRange<Double> {
    paddedDomain(store.samples.compactMap(\.systemPowerWatts), fallback: 0...10)
  }

  private func paddedDomain(
    _ values: [Double],
    fallback: ClosedRange<Double>
  ) -> ClosedRange<Double> {
    guard let minimum = values.min(), let maximum = values.max() else { return fallback }
    let span = maximum - minimum
    let padding = span > 0 ? span * 0.1 : max(abs(maximum) * 0.05, 1)
    return (minimum - padding)...(maximum + padding)
  }

  private func normalized(_ value: Double, in domain: ClosedRange<Double>) -> Double {
    (value - domain.lowerBound) / (domain.upperBound - domain.lowerBound)
  }

  private func denormalized(
    _ value: Double,
    in domain: ClosedRange<Double>
  ) -> Double {
    domain.lowerBound + value * (domain.upperBound - domain.lowerBound)
  }

  private var chartSamples: [SystemMetricSample] {
    let maximumPoints = 240
    guard store.samples.count > maximumPoints else { return store.samples }
    let stride = Int(ceil(Double(store.samples.count) / Double(maximumPoints)))
    return store.samples.enumerated().compactMap { index, sample in
      index.isMultiple(of: stride) ? sample : nil
    }
  }

  private func formattedBytes(_ bytes: UInt64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .memory
    return formatter.string(fromByteCount: Int64(bytes))
  }

  private func hoverOverlay(
    proxy: ChartProxy,
    geometry: GeometryProxy,
    metric: MetricKind,
    samples: [SystemMetricSample]
  ) -> some View {
    Rectangle()
      .fill(.clear)
      .contentShape(Rectangle())
      .onContinuousHover { phase in
        switch phase {
        case .active(let location):
          hoveredMetric = metric
          let plotFrame = geometry[proxy.plotAreaFrame]
          guard plotFrame.contains(location),
            let date: Date = proxy.value(atX: location.x - plotFrame.minX)
          else {
            selectedSample = nil
            return
          }
          selectedSample = nearestSample(to: date, in: samples)
        case .ended:
          if hoveredMetric == metric {
            hoveredMetric = nil
            selectedSample = nil
          }
        }
      }
  }

  private func nearestSample(
    to date: Date,
    in samples: [SystemMetricSample]
  ) -> SystemMetricSample? {
    samples.min {
      abs($0.capturedAt.timeIntervalSince(date)) < abs($1.capturedAt.timeIntervalSince(date))
    }
  }

  private func pressureTooltip(_ sample: SystemMetricSample) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(sample.capturedAt, format: .dateTime.hour().minute())
      Text("CPU \(sample.cpuPercent.map { String(format: "%.1f%%", $0) } ?? "—")")
      Text(String(format: "Memory %.1f%%", sample.memoryPercent))
    }
    .tooltipStyle()
  }

  private func batteryTooltip(_ sample: SystemMetricSample) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(sample.capturedAt, format: .dateTime.hour().minute())
      Text(sample.batteryTemperatureCelsius.map { String(format: "%.1f°C", $0) } ?? "—")
      Text(sample.systemPowerWatts.map { String(format: "%.2f W", $0) } ?? "—")
    }
    .tooltipStyle()
  }
}

private enum MetricKind: Hashable {
  case pressure
  case battery
}

extension View {
  fileprivate func tooltipStyle() -> some View {
    self
      .font(.caption2.monospacedDigit())
      .padding(6)
      .background(.regularMaterial)
      .clipShape(RoundedRectangle(cornerRadius: 6))
  }
}
