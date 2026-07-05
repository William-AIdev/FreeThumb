import AppKit
import FreeThumbCore
import SwiftUI

struct MenuBarContentView: View {
  @ObservedObject var controller: AppController

  @AppStorage("sessionMinutes") private var sessionMinutes = 120
  @AppStorage("batteryWarningPercent") private var batteryWarningPercent = 35
  @AppStorage("batteryStopPercent") private var batteryUrgentPercent = 20
  @AppStorage("alertsLocalEnabled") private var alertsLocalEnabled = true
  @AppStorage("alertsIMessageEnabled") private var alertsIMessageEnabled = false
  @AppStorage("alertsIMessageRecipient") private var alertsIMessageRecipient = ""
  @AppStorage("alertsEmailEnabled") private var alertsEmailEnabled = false
  @AppStorage("alertsEmailRecipient") private var alertsEmailRecipient = ""
  @AppStorage("alertsWebhookEnabled") private var alertsWebhookEnabled = false
  @AppStorage("alertsWebhookURL") private var alertsWebhookURL = ""
  @AppStorage("alertsPowerDisconnectEnabled") private var alertsPowerDisconnectEnabled = true
  @AppStorage("alertsLowPowerModeEnabled") private var alertsLowPowerModeEnabled = true
  @AppStorage("alertsThermalSustainSeconds") private var alertsThermalSustainSeconds = 30
  @AppStorage("alertsExpiryWarningMinutes") private var alertsExpiryWarningMinutes = 10
  @AppStorage("alertsCooldownMinutes") private var alertsCooldownMinutes = 15
  @AppStorage("showSystemPressureWidget") private var showSystemPressureWidget = true
  @AppStorage("showBatteryMetricsWidget") private var showBatteryMetricsWidget = true
  @AppStorage("showHighActivityAppsWidget") private var showHighActivityAppsWidget = false
  @State private var shouldStartAfterAuthorization = false
  @State private var showsAuthorizationExplanation = false
  private let durationOptions = [30, 60, 120, 240, 0]

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      controlsSection
        .padding(16)
      Divider()
      statusSection
        .padding(16)
      if showsMonitoringWidgets {
        Divider()
        MenuMetricsView(
          store: controller.metricsStore,
          showSystemPressure: showSystemPressureWidget,
          showBatteryMetrics: showBatteryMetricsWidget,
          showHighActivityApps: showHighActivityAppsWidget
        )
        .padding(16)
      }
      Divider()
      footer
    }
    .frame(width: 340)
    .onAppear { controller.setMenuVisible(true) }
    .onDisappear { controller.setMenuVisible(false) }
    .alert("Administrator approval required", isPresented: $showsAuthorizationExplanation) {
      Button("Cancel", role: .cancel) {
        shouldStartAfterAuthorization = false
      }
      Button("Continue") {
        if shouldStartAfterAuthorization {
          startProtection()
        }
        shouldStartAfterAuthorization = false
      }
    } message: {
      Text(
        "To keep this Mac running with the lid closed, macOS requires one-time approval for only ‘pmset disablesleep 0’ and ‘pmset disablesleep 1’. FreeThumb cannot read or store your password."
      )
    }
  }

  private var header: some View {
    HStack(spacing: 10) {
      Image(nsImage: controller.statusIconImage(pointSize: 22))
        .frame(width: 28, height: 28)
        .accessibilityLabel(controller.menuBarAccessibilityLabel)

      VStack(alignment: .leading, spacing: 2) {
        Text("FreeThumb")
          .font(.headline)
        Text(controller.isProtecting ? remainingText : localized("Ready"))
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Circle()
        .fill(statusColor)
        .frame(width: 8, height: 8)
        .accessibilityLabel(
          controller.isProtecting
            ? localized("Protection active") : localized("Protection inactive")
        )
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
        value: controller.snapshot.lowPowerModeEnabled ? localized("On") : localized("Off"),
        color: controller.snapshot.lowPowerModeEnabled ? .orange : .secondary
      )
      StatusRow(
        icon: controller.lidState == .closed ? "laptopcomputer.slash" : "laptopcomputer",
        title: "Lid",
        value: localized(controller.lidState.rawValue.capitalized),
        color: controller.lidState == .closed ? .blue : .secondary
      )

      if let warning = controller.warningMessage {
        messageBanner(warning, color: .orange, icon: "exclamationmark.triangle.fill")
      }

      if let error = controller.errorMessage {
        messageBanner(
          error,
          color: .red,
          icon: "exclamationmark.circle.fill",
          dismiss: controller.clearError
        )
      }

      if let info = controller.infoMessage {
        messageBanner(info, color: .blue, icon: "lock.fill")
          .onTapGesture { controller.clearInfo() }
      }
    }
  }

  private var controlsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Duration")
        Spacer()
        Text(localized(durationLabel(for: sessionMinutes)))
          .foregroundStyle(.secondary)
      }

      Slider(value: durationSliderValue, in: 0...Double(durationOptions.count - 1), step: 1)
        .labelsHidden()
        .overlay {
          GeometryReader { geometry in
            ForEach(durationOptions.indices, id: \.self) { index in
              Circle()
                .fill(index == selectedDurationIndex ? Color.accentColor : Color.secondary)
                .frame(width: 5, height: 5)
                .position(
                  x: durationTickPosition(index: index, width: geometry.size.width),
                  y: geometry.size.height / 2
                )
            }
          }
          .allowsHitTesting(false)
        }
        .disabled(controlsDisabled)

      HStack(spacing: 0) {
        ForEach(durationOptions, id: \.self) { minutes in
          Text(localized(durationLabel(for: minutes)))
            .font(.caption2)
            .foregroundStyle(minutes == sessionMinutes ? .primary : .secondary)
            .frame(maxWidth: .infinity)
        }
      }
      .padding(.horizontal, 5)

      Button {
        if controller.isProtecting {
          controller.stop()
        } else {
          requestStart()
        }
      } label: {
        if controller.isTransitioning {
          HStack {
            ProgressView()
              .controlSize(.small)
            Text(
              controller.isProtecting
                ? localized("Disabling Sleep Prevention Mode…")
                : localized("Enabling Sleep Prevention Mode…")
            )
          }
          .frame(maxWidth: .infinity)
        } else {
          Label(
            controller.isProtecting
              ? localized("Disable Sleep Prevention Mode")
              : localized("Enable Sleep Prevention Mode"),
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
      Spacer()
      if #available(macOS 14.0, *) {
        SettingsLink {
          Image(systemName: "gearshape")
        }
        .simultaneousGesture(
          TapGesture().onEnded {
            scheduleSettingsFocus()
          }
        )
        .buttonStyle(.plain)
        .help("Settings")
      } else {
        Button(action: openSettingsWindow) {
          Image(systemName: "gearshape")
        }
        .buttonStyle(.plain)
        .help("Settings")
      }
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
    .padding(.top, 12)
    .padding(.bottom, showsAllMonitoringWidgets ? 24 : 12)
  }

  private func messageBanner(
    _ message: String,
    color: Color,
    icon: String,
    dismiss: (() -> Void)? = nil
  ) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: icon)
      Text(message)
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
      if let dismiss {
        Button(action: dismiss) {
          Image(systemName: "xmark.circle.fill")
        }
        .buttonStyle(.plain)
        .help(localized("Dismiss"))
        .accessibilityLabel(localized("Dismiss"))
      }
    }
    .foregroundStyle(color)
    .padding(10)
    .background(color.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 6))
  }

  private var powerText: String {
    let source =
      switch controller.snapshot.powerSource {
      case .ac: localized("AC")
      case .battery: localized("Battery")
      case .unknown: localized("Unknown")
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
    localized(controller.snapshot.thermalLevel.rawValue.capitalized)
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
    switch controller.menuBarStatus {
    case .inactive: .secondary
    case .healthy: .green
    case .warning: .yellow
    case .critical: .red
    }
  }

  private var controlsDisabled: Bool {
    controller.isProtecting || controller.isTransitioning
  }

  private var selectedDurationIndex: Int {
    durationOptions.firstIndex(of: sessionMinutes) ?? 0
  }

  private var durationSliderValue: Binding<Double> {
    Binding(
      get: { Double(selectedDurationIndex) },
      set: { value in
        let index = min(max(Int(value.rounded()), 0), durationOptions.count - 1)
        sessionMinutes = durationOptions[index]
      }
    )
  }

  private func durationLabel(for minutes: Int) -> String {
    switch minutes {
    case 30: "30m"
    case 60: "1h"
    case 120: "2h"
    case 240: "4h"
    default: "∞"
    }
  }

  private func durationTickPosition(index: Int, width: CGFloat) -> CGFloat {
    let inset: CGFloat = 8
    let availableWidth = max(0, width - inset * 2)
    return inset + availableWidth * CGFloat(index) / CGFloat(durationOptions.count - 1)
  }

  private var showsMonitoringWidgets: Bool {
    showSystemPressureWidget || showBatteryMetricsWidget || showHighActivityAppsWidget
  }

  private var showsAllMonitoringWidgets: Bool {
    showSystemPressureWidget && showBatteryMetricsWidget && showHighActivityAppsWidget
  }

  private var remainingText: String {
    if controller.isUnlimitedSession { return localized("Unlimited") }
    let hours = controller.remainingSeconds / 3600
    let minutes = (controller.remainingSeconds % 3600) / 60
    let seconds = controller.remainingSeconds % 60
    if hours > 0 {
      return localizedFormat("%d:%02d:%02d remaining", hours, minutes, seconds)
    }
    return localizedFormat("%02d:%02d remaining", minutes, seconds)
  }

  private var alertConfiguration: SafetyAlertConfiguration {
    SafetyAlertConfiguration(
      localNotificationsEnabled: alertsLocalEnabled,
      iMessageEnabled: alertsIMessageEnabled,
      iMessageRecipient: alertsIMessageRecipient,
      emailEnabled: alertsEmailEnabled,
      emailRecipient: alertsEmailRecipient,
      webhookEnabled: alertsWebhookEnabled,
      webhookURL: alertsWebhookURL,
      alertOnPowerDisconnect: alertsPowerDisconnectEnabled,
      alertOnLowPowerMode: alertsLowPowerModeEnabled,
      thermalSustainSeconds: alertsThermalSustainSeconds,
      expiryWarningMinutes: alertsExpiryWarningMinutes,
      cooldownMinutes: alertsCooldownMinutes
    )
  }

  private func openSettingsWindow() {
    let application = NSApplication.shared
    application.activate(ignoringOtherApps: true)
    if !application.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
      application.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }

    scheduleSettingsFocus()
  }

  private func scheduleSettingsFocus() {
    NSApplication.shared.activate(ignoringOtherApps: true)
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(150))
      focusSettingsWindow()
      try? await Task.sleep(for: .milliseconds(350))
      focusSettingsWindow()
    }
  }

  private func focusSettingsWindow() {
    let application = NSApplication.shared
    application.activate(ignoringOtherApps: true)
    guard
      let window = application.windows.first(where: {
        $0.isVisible && $0.canBecomeKey && !($0 is NSPanel)
      })
    else { return }
    window.makeKeyAndOrderFront(nil)
  }

  private func requestStart() {
    guard controller.needsAdministratorAuthorization else {
      startProtection()
      return
    }
    shouldStartAfterAuthorization = true
    showsAuthorizationExplanation = true
  }

  private func startProtection() {
    controller.start(
      minutes: sessionMinutes,
      batteryWarningPercent: batteryWarningPercent,
      batteryUrgentPercent: batteryUrgentPercent,
      alertConfiguration: alertConfiguration
    )
  }
}

private struct StatusRow: View {
  let icon: String
  let title: LocalizedStringKey
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
