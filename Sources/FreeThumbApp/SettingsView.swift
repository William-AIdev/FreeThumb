import AppKit
import SwiftUI

struct SettingsView: View {
  let controller: AppController

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
  @AppStorage("updateManifestURL") private var updateManifestURL = defaultUpdateManifestURL
  @AppStorage("showSystemPressureWidget") private var showSystemPressureWidget = true
  @AppStorage("showBatteryMetricsWidget") private var showBatteryMetricsWidget = true
  @AppStorage("showHighActivityAppsWidget") private var showHighActivityAppsWidget = false
  @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue
  @StateObject private var loginItem = LoginItemController()
  @StateObject private var updateChecker = UpdateChecker()
  @State private var localNotificationStatus = "Checking system status…"

  var body: some View {
    TabView {
      generalSettings
        .tabItem { Label("General", systemImage: "gearshape") }
      protectionSettings
        .tabItem { Label("Protection", systemImage: "hand.thumbsup.fill") }
      alertSettings
        .tabItem { Label("Alerts", systemImage: "bell.badge.fill") }
      ActivityView(controller: controller)
        .tabItem { Label("Activity", systemImage: "chart.xyaxis.line") }
    }
    .frame(width: 640, height: 620)
  }

  private var generalSettings: some View {
    Form {
      Section("Language") {
        Picker("Language", selection: $appLanguage) {
          ForEach(AppLanguage.allCases) { language in
            Text(language.displayName).tag(language.rawValue)
          }
        }
        helpText("Language changes apply immediately.")
      }

      Section("Startup") {
        Toggle(
          "Launch FreeThumb at login",
          isOn: Binding(
            get: { loginItem.isEnabled },
            set: { loginItem.setEnabled($0) }
          )
        )
        if let message = loginItem.statusMessage {
          helpText(message)
        }
      }

      Section("Software updates") {
        TextField("HTTPS release manifest URL", text: $updateManifestURL)
        helpText(
          "The manifest is JSON with version and downloadURL fields. FreeThumb includes the official release source by default."
        )
        HStack {
          Button("Check for Updates") {
            updateChecker.check(manifestURLString: updateManifestURL)
          }
          .disabled(updateChecker.isChecking)
          if updateChecker.isChecking {
            ProgressView()
              .controlSize(.small)
          }
          if let downloadURL = updateChecker.downloadURL {
            Link("Open Download", destination: downloadURL)
          }
        }
        if let message = updateChecker.statusMessage {
          helpText(message)
        } else {
          helpText(localizedFormat("Current version: %@", updateChecker.currentVersion))
        }
      }

      Section("Menu bar monitoring") {
        Toggle("System pressure chart", isOn: $showSystemPressureWidget)
        Toggle("Battery temperature and total power chart", isOn: $showBatteryMetricsWidget)
        Toggle("High energy apps (estimated)", isOn: $showHighActivityAppsWidget)
        helpText(
          "Charts sample every 30 seconds and keep up to 24 hours in memory. High energy apps includes only third-party apps run by the current user. Its number is a long-term relative estimate from macOS top, averaged while monitoring is enabled; it is not watts."
        )
      }
      .onChange(of: showSystemPressureWidget) { _ in controller.metricsVisibilityChanged() }
      .onChange(of: showBatteryMetricsWidget) { _ in controller.metricsVisibilityChanged() }
      .onChange(of: showHighActivityAppsWidget) { _ in controller.metricsVisibilityChanged() }
    }
    .formStyle(.grouped)
  }

  private var protectionSettings: some View {
    Form {
      Section("Battery thresholds") {
        Stepper(
          localizedFormat("Warning at %d%%", batteryWarningPercent),
          value: $batteryWarningPercent,
          in: batteryUrgentPercent...100,
          step: 5
        )
        Stepper(
          localizedFormat("Urgent at %d%%", batteryUrgentPercent),
          value: $batteryUrgentPercent,
          in: 0...batteryWarningPercent,
          step: 5
        )
        helpText("These thresholds trigger alerts; they do not stop protection.")
      }

      Section("Automatic alert conditions") {
        Toggle("AC power is disconnected", isOn: $alertsPowerDisconnectEnabled)
        Toggle("Low Power Mode is enabled", isOn: $alertsLowPowerModeEnabled)

        settingPicker("Thermal pressure persists for", selection: $alertsThermalSustainSeconds) {
          Text("15 seconds").tag(15)
          Text("30 seconds").tag(30)
          Text("1 minute").tag(60)
          Text("2 minutes").tag(120)
        }

        settingPicker("Warn before session expires", selection: $alertsExpiryWarningMinutes) {
          Text("5 minutes").tag(5)
          Text("10 minutes").tag(10)
          Text("15 minutes").tag(15)
          Text("30 minutes").tag(30)
        }

        settingPicker("Repeat alert cooldown", selection: $alertsCooldownMinutes) {
          Text("1 minute").tag(1)
          Text("5 minutes").tag(5)
          Text("15 minutes").tag(15)
          Text("30 minutes").tag(30)
          Text("1 hour").tag(60)
        }
      }

      Section {
        helpText("Changes apply the next time protection starts.")
      }
    }
    .formStyle(.grouped)
  }

  private var alertSettings: some View {
    Form {
      Section("Delivery channels") {
        Toggle("Local notifications", isOn: $alertsLocalEnabled)
        helpText(
          "macOS asks for permission on first use. If blocked, enable FreeThumb in System Settings > Notifications."
        )
        helpText(localizedFormat("System status: %@", localNotificationStatus))
        HStack {
          Button("Refresh Status") {
            Task { await refreshLocalNotificationStatus() }
          }
          Button("Open Notification Settings") {
            openSystemNotificationSettings()
          }
        }

        Toggle("iMessage", isOn: $alertsIMessageEnabled)
        if alertsIMessageEnabled {
          TextField("Phone number or Apple Account", text: $alertsIMessageRecipient)
        }
        helpText("Messages must already be signed in. macOS may ask for automation permission.")

        Toggle("Email via Mail", isOn: $alertsEmailEnabled)
        if alertsEmailEnabled {
          TextField("Recipient email", text: $alertsEmailRecipient)
        }
        helpText(
          "Mail must have a working sending account. macOS may ask for automation permission."
        )

        Toggle("HTTPS webhook", isOn: $alertsWebhookEnabled)
        if alertsWebhookEnabled {
          TextField("https://example.com/alerts", text: $alertsWebhookURL)
          helpText("FreeThumb sends a JSON POST. The server must return a 2xx response.")
        }
      }

      Section("Test delivery") {
        HStack {
          Button("Test local notification") {
            controller.sendTestAlert(configuration: localNotificationConfiguration)
            Task {
              try? await Task.sleep(for: .seconds(2))
              await refreshLocalNotificationStatus()
            }
          }
          Button("Test enabled channels") {
            controller.sendTestAlert(configuration: alertConfiguration)
          }
          .disabled(!alertConfiguration.hasEnabledChannel)
        }
        AlertDeliveryStatusView(controller: controller)
      }
    }
    .formStyle(.grouped)
    .task {
      await refreshLocalNotificationStatus()
    }
  }

  private func settingPicker<Content: View>(
    _ title: LocalizedStringKey,
    selection: Binding<Int>,
    @ViewBuilder content: () -> Content
  ) -> some View {
    HStack {
      Text(title)
      Spacer()
      Picker(title, selection: selection, content: content)
        .labelsHidden()
        .frame(width: 130)
    }
  }

  private func helpText(_ text: String) -> some View {
    Text(LocalizedStringKey(text))
      .font(.caption)
      .foregroundStyle(.secondary)
  }

  private func refreshLocalNotificationStatus() async {
    localNotificationStatus = await NotificationService.authorizationSummary()
  }

  private func openSystemNotificationSettings() {
    guard
      let url = URL(
        string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
      )
    else { return }
    NSWorkspace.shared.open(url)
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

  private var localNotificationConfiguration: SafetyAlertConfiguration {
    SafetyAlertConfiguration(
      localNotificationsEnabled: true,
      iMessageEnabled: false,
      emailEnabled: false,
      webhookEnabled: false
    )
  }
}

private struct AlertDeliveryStatusView: View {
  @ObservedObject var controller: AppController

  var body: some View {
    if let error = controller.errorMessage {
      Label(error, systemImage: "xmark.octagon.fill")
        .foregroundStyle(.red)
    } else if let info = controller.infoMessage {
      Label(info, systemImage: "checkmark.circle.fill")
        .foregroundStyle(.green)
    } else {
      Text("Keep this window open while testing so delivery errors remain visible.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}
