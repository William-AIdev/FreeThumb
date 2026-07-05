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
  let activityStore: ActivityStore
  let metricsStore = SystemMetricsStore()

  private let systemMonitor = MacSystemMonitor()
  private let performanceMetricsMonitor = PerformanceMetricsMonitor()
  private let highActivityAppMonitor = HighActivityAppMonitor()
  private let powerSourceMonitor = PowerSourceEventMonitor()
  private let lidMonitor = LidStateMonitor()
  private let displayController = BuiltInDisplayController()
  private let assertion = SleepAssertion()
  private let closedLidController = ClosedLidController()
  private let alertDelivery = SafetyAlertDelivery()
  private var policy = ProtectionPolicy()
  private var alertConfiguration = SafetyAlertConfiguration()
  private var alertThrottle = SafetyAlertThrottle(cooldownSeconds: 15 * 60)
  private var endDate: Date?
  private var safetyMonitoringTask: Task<Void, Never>?
  private var lidMonitoringTask: Task<Void, Never>?
  private var countdownTask: Task<Void, Never>?
  private var metricsMonitoringTask: Task<Void, Never>?
  private var warningSeverity: SafetyAlertSeverity?
  private var alertTriggerEvaluator = SafetyAlertTriggerEvaluator()
  private var lastActivitySampleAt: Date?
  private var lastHighActivitySampleAt: Date?
  private var metricSamples: [SystemMetricSample] = []
  private var isMenuVisible = false

  init() {
    UserDefaults.standard.register(
      defaults: [
        "activityTrackingEnabled": true,
        "showSystemPressureWidget": true,
        "showBatteryMetricsWidget": true,
        "showHighActivityAppsWidget": false,
        "updateManifestURL": defaultUpdateManifestURL,
      ]
    )
    activityStore = ActivityStore(
      isEnabled: UserDefaults.standard.bool(forKey: "activityTrackingEnabled")
    )
    snapshot = systemMonitor.snapshot()
    lidState = lidMonitor.currentState()
    powerSourceMonitor.start { [weak self] in
      self?.refreshSafetyState()
    }
    restartSafetyMonitoring()
    restartLidMonitoring()
    restartMetricsMonitoring()
  }

  private func restartSafetyMonitoring() {
    safetyMonitoringTask?.cancel()
    let interval = isProtecting ? 30 : 60
    safetyMonitoringTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(interval))
        guard !Task.isCancelled else { return }
        self?.refreshSafetyState()
      }
    }
  }

  private func restartLidMonitoring() {
    lidMonitoringTask?.cancel()
    let interval = isProtecting ? 2 : 10
    lidMonitoringTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(interval))
        guard !Task.isCancelled else { return }
        self?.updateLidState()
      }
    }
  }

  var menuBarIconName: String {
    "hand.thumbsup.fill"
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

  var needsAdministratorAuthorization: Bool {
    ClosedLidController.needsAdministratorAuthorization()
  }

  var isUnlimitedSession: Bool {
    isProtecting && endDate == nil
  }

  func statusIconImage(pointSize: CGFloat) -> NSImage {
    let image =
      NSImage(
        systemSymbolName: menuBarIconName,
        accessibilityDescription: menuBarAccessibilityLabel
      ) ?? NSImage()
    let size = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
    let palette = NSImage.SymbolConfiguration(paletteColors: [statusIconColor])
    let coloredImage = image.withSymbolConfiguration(size.applying(palette)) ?? image
    coloredImage.isTemplate = false
    return coloredImage
  }

  func start(
    minutes: Int,
    batteryWarningPercent: Int,
    batteryUrgentPercent: Int,
    alertConfiguration: SafetyAlertConfiguration
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
      let duration = minutes > 0 ? TimeInterval(minutes * 60) : nil
      do {
        _ = try await closedLidController.enable()

        do {
          try assertion.start(duration: duration)
        } catch {
          try? await closedLidController.disable()
          throw error
        }

        endDate = duration.map { Date().addingTimeInterval($0) }
        remainingSeconds = Int(duration ?? 0)
        isProtecting = true
        restartSafetyMonitoring()
        restartLidMonitoring()
        startCountdownIfNeeded()
        warningMessage = nil
        warningSeverity = nil
        alertTriggerEvaluator = SafetyAlertTriggerEvaluator()
        if activityStore.isEnabled {
          startActivityTracking()
        }
        Task {
          await alertDelivery.prepare(configuration: alertConfiguration)
        }
        updateWarningState()
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

  func clearError() {
    errorMessage = nil
  }

  func clearInfo() {
    infoMessage = nil
  }

  func setActivityTrackingEnabled(_ enabled: Bool) {
    guard enabled != activityStore.isEnabled else { return }
    activityStore.setEnabled(enabled)
    UserDefaults.standard.set(enabled, forKey: "activityTrackingEnabled")

    guard isProtecting else { return }
    if enabled {
      startActivityTracking()
    } else {
      finishActivityTracking()
    }
  }

  func metricsVisibilityChanged() {
    restartMetricsMonitoring()
  }

  func setMenuVisible(_ visible: Bool) {
    guard visible != isMenuVisible else { return }
    isMenuVisible = visible
    if visible {
      metricsStore.replaceSamples(metricSamples)
    }
    restartMetricsMonitoring()
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

  private func refreshSafetyState() {
    let previousSnapshot = snapshot
    snapshot = systemMonitor.snapshot()

    guard isProtecting, !isTransitioning else { return }
    if activityStore.isEnabled {
      recordActivityIfNeeded()
    }

    evaluateSafetyAlerts(previousSnapshot: previousSnapshot)
    updateWarningState()
  }

  private func updateWarningState() {
    switch policy.evaluate(snapshot) {
    case .continueRunning:
      warningMessage = nil
      warningSeverity = nil
    case .warn(let reason):
      warningMessage = reason
      warningSeverity = severity(for: snapshot)
    }
  }

  private func startCountdownIfNeeded() {
    countdownTask?.cancel()
    guard endDate != nil else { return }

    countdownTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1))
        guard !Task.isCancelled, let self, let endDate = self.endDate else { return }
        self.remainingSeconds = max(0, Int(endDate.timeIntervalSinceNow.rounded(.up)))
        guard self.remainingSeconds == 0 else { continue }
        self.sendSafetyAlert(
          key: "session-expired",
          title: "FreeThumb session expired",
          condition: "The protection timer expired",
          ignoringCooldown: true
        )
        self.requestStop(message: "The protection timer expired", quitAfterStop: false)
        return
      }
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
      if activityStore.isEnabled {
        finishActivityTracking()
      }
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
      countdownTask?.cancel()
      countdownTask = nil
      isProtecting = false
      restartSafetyMonitoring()
      restartLidMonitoring()
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
    safetyMonitoringTask?.cancel()
    lidMonitoringTask?.cancel()
    countdownTask?.cancel()
    metricsMonitoringTask?.cancel()
  }

  private func restartMetricsMonitoring() {
    metricsMonitoringTask?.cancel()
    guard shouldMonitorMetrics else { return }

    metricsMonitoringTask = Task { [weak self] in
      while !Task.isCancelled {
        await self?.sampleSystemMetrics()
        let interval = self?.metricsMonitoringIntervalSeconds ?? 60
        try? await Task.sleep(for: .seconds(interval))
      }
    }
  }

  private func sampleSystemMetrics() async {
    let defaults = UserDefaults.standard
    let showsGraph =
      defaults.bool(forKey: "showSystemPressureWidget")
      || defaults.bool(forKey: "showBatteryMetricsWidget")
    let now = Date()
    let graphSampleIsDue =
      metricSamples.last.map { now.timeIntervalSince($0.capturedAt) >= 30 } ?? true
    if showsGraph && graphSampleIsDue {
      let metric = performanceMetricsMonitor.snapshot()
      metricSamples.append(
        SystemMetricSample(
          capturedAt: metric.capturedAt,
          cpuPercent: metric.cpuPercent,
          memoryUsedBytes: metric.memoryUsedBytes,
          memoryPercent: metric.memoryPercent,
          batteryTemperatureCelsius: metric.batteryTemperatureCelsius,
          systemPowerWatts: metric.systemPowerWatts
        )
      )
      if metricSamples.count > 2_880 {
        metricSamples.removeFirst(metricSamples.count - 2_880)
      }
      if isMenuVisible {
        metricsStore.replaceSamples(metricSamples)
      }
    }

    let highActivityInterval: TimeInterval = isMenuVisible ? 60 : 5 * 60
    let highActivitySampleIsDue =
      lastHighActivitySampleAt.map { now.timeIntervalSince($0) >= highActivityInterval } ?? true
    if defaults.bool(forKey: "showHighActivityAppsWidget") && highActivitySampleIsDue {
      metricsStore.replaceHighActivityApps(await highActivityAppMonitor.sample())
      lastHighActivitySampleAt = Date()
    }
  }

  private var shouldMonitorMetrics: Bool {
    let defaults = UserDefaults.standard
    return defaults.bool(forKey: "showSystemPressureWidget")
      || defaults.bool(forKey: "showBatteryMetricsWidget")
      || defaults.bool(forKey: "showHighActivityAppsWidget")
  }

  private var metricsMonitoringIntervalSeconds: TimeInterval {
    let defaults = UserDefaults.standard
    let showsGraph =
      defaults.bool(forKey: "showSystemPressureWidget")
      || defaults.bool(forKey: "showBatteryMetricsWidget")
    if showsGraph { return 30 }
    return isMenuVisible ? 60 : 5 * 60
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
      remainingSeconds: isUnlimitedSession ? Int.max : remainingSeconds,
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
      ? isUnlimitedSession
        ? "Protection active with no time limit."
        : "Protection active; \(formattedDuration(remainingSeconds)) remaining."
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

  private var statusIconColor: NSColor {
    switch menuBarStatus {
    case .inactive: .labelColor
    case .healthy: .systemGreen
    case .warning: .systemYellow
    case .critical: .systemRed
    }
  }

  private func startActivityTracking() {
    var tracker = SessionActivityTracker()
    let sample = activitySample()
    tracker.start(with: sample)
    activityStore.replaceTracker(tracker)
    lastActivitySampleAt = sample.capturedAt
  }

  private func recordActivityIfNeeded() {
    let now = Date()
    guard lastActivitySampleAt.map({ now.timeIntervalSince($0) >= 60 }) ?? true else { return }
    var tracker = activityStore.tracker
    let sample = activitySample(at: now)
    tracker.record(sample)
    activityStore.replaceTracker(tracker)
    lastActivitySampleAt = sample.capturedAt
  }

  private func finishActivityTracking() {
    guard isProtecting, activityStore.tracker.endedAt == nil else { return }
    var tracker = activityStore.tracker
    tracker.finish(with: activitySample())
    activityStore.replaceTracker(tracker)
    lastActivitySampleAt = nil
  }

  private func activitySample(at date: Date = Date()) -> SessionActivitySample {
    SessionActivitySample(
      capturedAt: date,
      powerSource: snapshot.powerSource,
      batteryPercent: snapshot.batteryPercent,
      thermalLevel: snapshot.thermalLevel,
      foregroundApp: NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
    )
  }
}
