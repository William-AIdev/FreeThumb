import AppKit
import Foundation
import FreeThumbCore
import FreeThumbMac

enum MenuBarStatus {
  case inactive
  case healthy
  case warning
  case critical
}

private enum SafetyAlertSeverity {
  case warning
  case critical
}

@MainActor
final class AppController: ObservableObject {
  @Published private(set) var snapshot: SystemSnapshot
  @Published private(set) var lidState: LidState
  @Published private(set) var isProtecting = false
  @Published private(set) var isTransitioning = false
  @Published private(set) var remainingSeconds = 0
  @Published private(set) var warningMessage: String?
  @Published private(set) var errorMessage: String?
  @Published private(set) var infoMessage: String?

  private let systemMonitor = MacSystemMonitor()
  private let lidMonitor = LidStateMonitor()
  private let displayController = BuiltInDisplayController()
  private let assertion = SleepAssertion()
  private let closedLidController = ClosedLidController()
  private let alertDelivery = SafetyAlertDelivery()
  private var policy = ProtectionPolicy()
  private var alertConfiguration = SafetyAlertConfiguration()
  private var alertThrottle = SafetyAlertThrottle(cooldownSeconds: 15 * 60)
  private var endDate: Date?
  private var monitoringTask: Task<Void, Never>?
  private var warningSeverity: SafetyAlertSeverity?
  private var alertTriggerEvaluator = SafetyAlertTriggerEvaluator()

  init() {
    snapshot = systemMonitor.snapshot()
    lidState = lidMonitor.currentState()
    monitoringTask = Task { [weak self] in
      while !Task.isCancelled {
        self?.tick()
        try? await Task.sleep(for: .seconds(1))
      }
    }
  }

  var menuBarIconName: String {
    switch menuBarStatus {
    case .inactive: "hand.thumbsup"
    case .healthy: "hand.thumbsup.fill"
    case .warning: "exclamationmark.triangle.fill"
    case .critical: "xmark.octagon.fill"
    }
  }

  var menuBarStatus: MenuBarStatus {
    if errorMessage != nil || warningSeverity == .critical { return .critical }
    if warningMessage != nil { return .warning }
    return isProtecting ? .healthy : .inactive
  }

  var menuBarAccessibilityLabel: String {
    switch menuBarStatus {
    case .inactive: "FreeThumb protection inactive"
    case .healthy: "FreeThumb protection active and healthy"
    case .warning: "FreeThumb warning"
    case .critical: "FreeThumb critical alert"
    }
  }

  func start(
    minutes: Int,
    batteryWarningPercent: Int,
    batteryUrgentPercent: Int,
    alertConfiguration: SafetyAlertConfiguration,
    showLockInstructionsAfterStart: Bool = false
  ) {
    guard !isProtecting, !isTransitioning else { return }

    snapshot = systemMonitor.snapshot()
    policy = ProtectionPolicy(
      batteryWarningPercent: batteryWarningPercent,
      batteryUrgentPercent: batteryUrgentPercent
    )
    self.alertConfiguration = alertConfiguration
    alertThrottle = SafetyAlertThrottle(
      cooldownSeconds: TimeInterval(alertConfiguration.cooldownMinutes * 60)
    )

    isTransitioning = true
    errorMessage = nil
    infoMessage = nil
    Task {
      let duration = TimeInterval(minutes * 60)
      do {
        _ = try await closedLidController.enable()

        do {
          try assertion.start(duration: duration)
        } catch {
          try? await closedLidController.disable()
          throw error
        }

        endDate = Date().addingTimeInterval(duration)
        remainingSeconds = Int(duration)
        isProtecting = true
        warningMessage = nil
        warningSeverity = nil
        alertTriggerEvaluator = SafetyAlertTriggerEvaluator()
        Task {
          await alertDelivery.prepare(configuration: alertConfiguration)
        }
        if showLockInstructionsAfterStart {
          infoMessage = "Protection is active. Press Control-Command-Q to lock your Mac."
        }
      } catch {
        errorMessage = String(describing: error)
      }
      isTransitioning = false
    }
  }

  func stop() {
    requestStop(message: nil, quitAfterStop: false)
  }

  func quit() {
    guard !isTransitioning else { return }
    guard isProtecting else {
      NSApplication.shared.terminate(nil)
      return
    }
    requestStop(message: nil, quitAfterStop: true)
  }

  func lockAndKeepRunning(
    minutes: Int,
    batteryWarningPercent: Int,
    batteryUrgentPercent: Int,
    alertConfiguration: SafetyAlertConfiguration
  ) {
    if isProtecting {
      infoMessage = "Protection is active. Press Control-Command-Q to lock your Mac."
      return
    }
    start(
      minutes: minutes,
      batteryWarningPercent: batteryWarningPercent,
      batteryUrgentPercent: batteryUrgentPercent,
      alertConfiguration: alertConfiguration,
      showLockInstructionsAfterStart: true
    )
  }

  func clearError() {
    errorMessage = nil
  }

  func clearInfo() {
    infoMessage = nil
  }

  func sendTestAlert(configuration: SafetyAlertConfiguration) {
    guard !isTransitioning else { return }
    infoMessage = nil
    errorMessage = nil
    guard configuration.hasEnabledChannel else {
      errorMessage = "Enable at least one alert channel before sending a test."
      return
    }

    let message = SafetyAlertMessage(
      title: "FreeThumb test alert",
      body: "Safety alert delivery is configured correctly. Protection inactive."
    )
    Task { [weak self] in
      guard let self else { return }
      await self.alertDelivery.prepare(configuration: configuration)
      let failures = await self.alertDelivery.send(message, configuration: configuration)
      if failures.isEmpty {
        self.infoMessage = "Test alert sent to all enabled channels."
      } else {
        self.errorMessage = "Test alert failed: \(failures.joined(separator: "; "))"
      }
    }
  }

  private func tick() {
    let previousSnapshot = snapshot
    snapshot = systemMonitor.snapshot()
    updateLidState()

    guard isProtecting, !isTransitioning, let endDate else { return }

    remainingSeconds = max(0, Int(endDate.timeIntervalSinceNow.rounded(.up)))
    if remainingSeconds == 0 {
      sendSafetyAlert(
        key: "session-expired",
        title: "FreeThumb session expired",
        condition: "The protection timer expired",
        ignoringCooldown: true
      )
      requestStop(message: "The protection timer expired", quitAfterStop: false)
      return
    }

    evaluateSafetyAlerts(previousSnapshot: previousSnapshot)

    switch policy.evaluate(snapshot) {
    case .continueRunning:
      warningMessage = nil
      warningSeverity = nil
    case .warn(let reason):
      warningMessage = reason
      warningSeverity = severity(for: snapshot)
    }
  }

  private func updateLidState() {
    let newState = lidMonitor.currentState()
    guard newState != lidState else { return }
    lidState = newState

    guard isProtecting else { return }
    switch newState {
    case .closed:
      do {
        try displayController.turnOffBuiltInDisplays()
      } catch {
        errorMessage = String(describing: error)
      }
    case .open:
      do {
        try displayController.restoreBuiltInDisplays()
      } catch {
        errorMessage = String(describing: error)
      }
    case .unknown:
      break
    }
  }

  private func requestStop(message: String?, quitAfterStop: Bool) {
    guard isProtecting, !isTransitioning else { return }
    isTransitioning = true

    Task {
      do {
        try displayController.restoreBuiltInDisplays()
      } catch {
        errorMessage = String(describing: error)
        sendRestoreFailureAlert(errorMessage ?? "Unable to restore display brightness")
        isTransitioning = false
        return
      }

      do {
        try await closedLidController.disable()
      } catch {
        errorMessage = "Sleep protection is still active. \(error)"
        sendRestoreFailureAlert(errorMessage ?? "Unable to restore sleep")
        isTransitioning = false
        return
      }

      assertion.stop()
      isProtecting = false
      endDate = nil
      remainingSeconds = 0
      warningMessage = nil
      warningSeverity = nil
      infoMessage = nil
      isTransitioning = false

      if let message {
        errorMessage = message
      }

      if quitAfterStop {
        NSApplication.shared.terminate(nil)
      }
    }
  }

  deinit {
    monitoringTask?.cancel()
  }

  private func evaluateSafetyAlerts(previousSnapshot: SystemSnapshot) {
    let evaluationConfiguration = SafetyAlertEvaluationConfiguration(
      batteryWarningPercent: policy.batteryWarningPercent,
      batteryUrgentPercent: policy.batteryUrgentPercent,
      alertOnPowerDisconnect: alertConfiguration.alertOnPowerDisconnect,
      alertOnLowPowerMode: alertConfiguration.alertOnLowPowerMode,
      thermalSustainSeconds: alertConfiguration.thermalSustainSeconds,
      expiryWarningSeconds: alertConfiguration.expiryWarningMinutes * 60
    )
    let triggers = alertTriggerEvaluator.evaluate(
      previous: previousSnapshot,
      current: snapshot,
      remainingSeconds: remainingSeconds,
      configuration: evaluationConfiguration
    )
    for trigger in triggers {
      sendSafetyAlert(trigger)
    }
  }

  private func sendRestoreFailureAlert(_ condition: String) {
    sendSafetyAlert(
      key: "restore-failed",
      title: "FreeThumb failed to restore normal sleep",
      condition: condition,
      ignoringCooldown: true
    )
  }

  private func sendSafetyAlert(_ trigger: SafetyAlertTrigger) {
    switch trigger {
    case .powerDisconnected:
      sendSafetyAlert(
        key: "power-disconnected",
        title: "FreeThumb power warning",
        condition: "AC power was disconnected; protection remains active"
      )
    case .batteryWarning(let percent, let threshold):
      sendSafetyAlert(
        key: "battery-warning",
        title: "FreeThumb battery warning",
        condition: "Battery is at \(percent)% (warning threshold: \(threshold)%)"
      )
    case .batteryUrgent(let percent, let threshold):
      sendSafetyAlert(
        key: "battery-urgent",
        title: "FreeThumb critical battery alert",
        condition: "Battery is at \(percent)% (urgent threshold: \(threshold)%)"
      )
    case .thermalSerious(let sustainedSeconds):
      sendSafetyAlert(
        key: "thermal-serious",
        title: "FreeThumb thermal warning",
        condition:
          "System thermal pressure remained serious for at least \(sustainedSeconds) seconds"
      )
    case .thermalCritical(let sustainedSeconds):
      sendSafetyAlert(
        key: "thermal-critical",
        title: "FreeThumb critical thermal alert",
        condition:
          "System thermal pressure remained critical for at least \(sustainedSeconds) seconds"
      )
    case .lowPowerMode:
      sendSafetyAlert(
        key: "low-power-mode",
        title: "FreeThumb power warning",
        condition: "Low Power Mode is enabled"
      )
    case .sessionExpiring(let remainingSeconds):
      sendSafetyAlert(
        key: "session-expiring",
        title: "FreeThumb session ending soon",
        condition: "Protection expires in \(formattedDuration(remainingSeconds))"
      )
    }
  }

  private func sendSafetyAlert(
    key: String,
    title: String,
    condition: String,
    ignoringCooldown: Bool = false
  ) {
    guard
      alertThrottle.shouldSend(
        key: key,
        ignoringCooldown: ignoringCooldown
      )
    else { return }

    let state =
      isProtecting
      ? "Protection active; \(formattedDuration(remainingSeconds)) remaining."
      : "Protection inactive."
    let message = SafetyAlertMessage(title: title, body: "\(condition). \(state)")
    let configuration = alertConfiguration

    Task { [weak self] in
      guard let self else { return }
      let failures = await self.alertDelivery.send(message, configuration: configuration)
      if !failures.isEmpty {
        let deliveryError = "Alert delivery failed: \(failures.joined(separator: "; "))"
        if let existingError = self.errorMessage {
          self.errorMessage = "\(existingError) \(deliveryError)"
        } else {
          self.errorMessage = deliveryError
        }
      }
    }
  }

  private func severity(for snapshot: SystemSnapshot) -> SafetyAlertSeverity {
    if snapshot.thermalLevel == .critical { return .critical }
    if snapshot.powerSource == .battery,
      let batteryPercent = snapshot.batteryPercent,
      batteryPercent <= policy.batteryUrgentPercent
    {
      return .critical
    }
    return .warning
  }

  private func formattedDuration(_ seconds: Int) -> String {
    let minutes = max(0, seconds) / 60
    let remainder = max(0, seconds) % 60
    return String(format: "%d:%02d", minutes, remainder)
  }
}
