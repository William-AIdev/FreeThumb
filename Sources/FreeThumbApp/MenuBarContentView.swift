import AppKit
import FreeThumbCore
import SwiftUI

struct MenuBarContentView: View {
  @ObservedObject var controller: AppController

  @AppStorage("sessionMinutes") private var sessionMinutes = 120
  @AppStorage("batteryWarningPercent") private var batteryWarningPercent = 35
  @AppStorage("batteryStopPercent") private var batteryUrgentPercent = 20

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      statusSection
        .padding(16)
      Divider()
      controlsSection
        .padding(16)
      Divider()
      footer
    }
    .frame(width: 340)
  }

  private var header: some View {
    HStack(spacing: 10) {
      Image(systemName: controller.menuBarIconName)
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(statusColor)
        .frame(width: 28, height: 28)

      VStack(alignment: .leading, spacing: 2) {
        Text("FreeThumb")
          .font(.headline)
        Text(controller.isProtecting ? remainingText : "Ready")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Circle()
        .fill(statusColor)
        .frame(width: 8, height: 8)
        .accessibilityLabel(controller.isProtecting ? "Protection active" : "Protection inactive")
    }
    .padding(16)
  }

  private var statusSection: some View {
    VStack(spacing: 12) {
      StatusRow(
        icon: powerIcon,
        title: "Power",
        value: powerText,
        color: controller.snapshot.powerSource == .battery ? .orange : .green
      )
      StatusRow(
        icon: "thermometer.medium",
        title: "Thermal",
        value: thermalText,
        color: thermalColor
      )
      StatusRow(
        icon: "leaf.fill",
        title: "Low Power Mode",
        value: controller.snapshot.lowPowerModeEnabled ? "On" : "Off",
        color: controller.snapshot.lowPowerModeEnabled ? .orange : .secondary
      )
      StatusRow(
        icon: controller.lidState == .closed ? "laptopcomputer.slash" : "laptopcomputer",
        title: "Lid",
        value: controller.lidState.rawValue.capitalized,
        color: controller.lidState == .closed ? .blue : .secondary
      )

      if let warning = controller.warningMessage {
        messageBanner(warning, color: .orange, icon: "exclamationmark.triangle.fill")
      }

      if let error = controller.errorMessage {
        messageBanner(error, color: .red, icon: "xmark.octagon.fill")
          .onTapGesture { controller.clearError() }
      }
    }
  }

  private var controlsSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("SESSION")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)

      Picker("Duration", selection: $sessionMinutes) {
        Text("30m").tag(30)
        Text("1h").tag(60)
        Text("2h").tag(120)
        Text("4h").tag(240)
      }
      .pickerStyle(.segmented)
      .disabled(controlsDisabled)

      DisclosureGroup("Battery alerts") {
        VStack(spacing: 10) {
          Stepper(
            "Warn at \(batteryWarningPercent)%",
            value: $batteryWarningPercent,
            in: max(batteryUrgentPercent, 20)...60,
            step: 5
          )
          Stepper(
            "Urgent at \(batteryUrgentPercent)%",
            value: $batteryUrgentPercent,
            in: 10...min(batteryWarningPercent, 40),
            step: 5
          )
        }
        .padding(.top, 8)
      }
      .disabled(controlsDisabled)

      Button {
        if controller.isProtecting {
          controller.stop()
        } else {
          controller.start(
            minutes: sessionMinutes,
            batteryWarningPercent: batteryWarningPercent,
            batteryUrgentPercent: batteryUrgentPercent
          )
        }
      } label: {
        if controller.isTransitioning {
          HStack {
            ProgressView()
              .controlSize(.small)
            Text(controller.isProtecting ? "Restoring sleep…" : "Starting…")
          }
          .frame(maxWidth: .infinity)
        } else {
          Label(
            controller.isProtecting ? "Stop protection" : "Start protection",
            systemImage: controller.isProtecting ? "stop.fill" : "play.fill"
          )
          .frame(maxWidth: .infinity)
        }
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .tint(controller.isProtecting ? .red : .accentColor)
      .disabled(controller.isTransitioning)
    }
  }

  private var footer: some View {
    HStack {
      Text(footerText)
        .font(.caption)
        .foregroundStyle(.secondary)
      Spacer()
      Button {
        controller.quit()
      } label: {
        Image(systemName: "power")
      }
      .buttonStyle(.plain)
      .help("Quit FreeThumb")
      .disabled(controller.isTransitioning)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  private func messageBanner(_ message: String, color: Color, icon: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: icon)
      Text(message)
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .foregroundStyle(color)
    .padding(10)
    .background(color.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 6))
  }

  private var powerText: String {
    let source =
      switch controller.snapshot.powerSource {
      case .ac: "AC"
      case .battery: "Battery"
      case .unknown: "Unknown"
      }
    guard let percent = controller.snapshot.batteryPercent else { return source }
    return "\(source) · \(percent)%"
  }

  private var powerIcon: String {
    switch controller.snapshot.powerSource {
    case .ac: "powerplug.fill"
    case .battery: "battery.50percent"
    case .unknown: "questionmark.circle"
    }
  }

  private var thermalText: String {
    controller.snapshot.thermalLevel.rawValue.capitalized
  }

  private var thermalColor: Color {
    switch controller.snapshot.thermalLevel {
    case .nominal: .green
    case .fair: .yellow
    case .serious: .orange
    case .critical: .red
    case .unknown: .secondary
    }
  }

  private var statusColor: Color {
    if controller.errorMessage != nil { return .red }
    if controller.warningMessage != nil { return .orange }
    return controller.isProtecting ? .green : .secondary
  }

  private var controlsDisabled: Bool {
    controller.isProtecting || controller.isTransitioning
  }

  private var footerText: String {
    if controller.isProtecting {
      return "System sleep disabled"
    }
    return "Changes sleep settings while active"
  }

  private var remainingText: String {
    let hours = controller.remainingSeconds / 3600
    let minutes = (controller.remainingSeconds % 3600) / 60
    let seconds = controller.remainingSeconds % 60
    if hours > 0 {
      return String(format: "%d:%02d:%02d remaining", hours, minutes, seconds)
    }
    return String(format: "%02d:%02d remaining", minutes, seconds)
  }
}

private struct StatusRow: View {
  let icon: String
  let title: String
  let value: String
  let color: Color

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: icon)
        .foregroundStyle(color)
        .frame(width: 20)
      Text(title)
        .foregroundStyle(.secondary)
      Spacer()
      Text(value)
        .fontWeight(.medium)
    }
    .font(.subheadline)
  }
}
