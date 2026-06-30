import AppKit
import Foundation
import FreeThumbCore
import FreeThumbMac

@MainActor
final class AppController: ObservableObject {
  @Published private(set) var snapshot: SystemSnapshot
  @Published private(set) var lidState: LidState
  @Published private(set) var isProtecting = false
  @Published private(set) var isTransitioning = false
  @Published private(set) var remainingSeconds = 0
  @Published private(set) var warningMessage: String?
  @Published private(set) var errorMessage: String?

  private let systemMonitor = MacSystemMonitor()
  private let lidMonitor = LidStateMonitor()
  private let displayController = BuiltInDisplayController()
  private let assertion = SleepAssertion()
  private let closedLidController = ClosedLidController()
  private let notifications = NotificationService()
  private var policy = ProtectionPolicy()
  private var endDate: Date?
  private var monitoringTask: Task<Void, Never>?
  private var lastNotifiedWarning: String?

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
    if isProtecting {
      return warningMessage == nil ? "hand.thumbsup.fill" : "exclamationmark.triangle.fill"
    }
    return "hand.thumbsup"
  }

  func start(
    minutes: Int,
    batteryWarningPercent: Int,
    batteryUrgentPercent: Int
  ) {
    guard !isProtecting, !isTransitioning else { return }

    snapshot = systemMonitor.snapshot()
    policy = ProtectionPolicy(
      batteryWarningPercent: batteryWarningPercent,
      batteryUrgentPercent: batteryUrgentPercent
    )

    isTransitioning = true
    errorMessage = nil
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
        lastNotifiedWarning = nil
        notifications.prepare()
      } catch {
        errorMessage = String(describing: error)
      }
      isTransitioning = false
    }
  }

  func stop() {
    requestStop(message: nil, notify: false, quitAfterStop: false)
  }

  func quit() {
    guard !isTransitioning else { return }
    guard isProtecting else {
      NSApplication.shared.terminate(nil)
      return
    }
    requestStop(message: nil, notify: false, quitAfterStop: true)
  }

  func clearError() {
    errorMessage = nil
  }

  private func tick() {
    snapshot = systemMonitor.snapshot()
    updateLidState()

    guard isProtecting, !isTransitioning, let endDate else { return }

    remainingSeconds = max(0, Int(endDate.timeIntervalSinceNow.rounded(.up)))
    if remainingSeconds == 0 {
      requestStop(message: "The protection timer expired", notify: true, quitAfterStop: false)
      return
    }

    switch policy.evaluate(snapshot) {
    case .continueRunning:
      warningMessage = nil
      lastNotifiedWarning = nil
    case .warn(let reason):
      warningMessage = reason
      if lastNotifiedWarning != reason {
        notifications.send(title: "FreeThumb warning", body: reason)
        lastNotifiedWarning = reason
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

  private func requestStop(message: String?, notify: Bool, quitAfterStop: Bool) {
    guard isProtecting, !isTransitioning else { return }
    isTransitioning = true

    Task {
      do {
        try displayController.restoreBuiltInDisplays()
      } catch {
        errorMessage = String(describing: error)
        isTransitioning = false
        return
      }

      do {
        try await closedLidController.disable()
      } catch {
        errorMessage = "Sleep protection is still active. \(error)"
        isTransitioning = false
        return
      }

      assertion.stop()
      isProtecting = false
      endDate = nil
      remainingSeconds = 0
      warningMessage = nil
      lastNotifiedWarning = nil
      isTransitioning = false

      if let message {
        errorMessage = message
        if notify {
          notifications.send(title: "FreeThumb stopped", body: message)
        }
      }

      if quitAfterStop {
        NSApplication.shared.terminate(nil)
      }
    }
  }

  deinit {
    monitoringTask?.cancel()
  }
}
