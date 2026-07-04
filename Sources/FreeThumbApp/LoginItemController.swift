import ServiceManagement

@MainActor
final class LoginItemController: ObservableObject {
  @Published private(set) var isEnabled = false
  @Published private(set) var statusMessage: String?

  init() {
    refresh()
  }

  func setEnabled(_ enabled: Bool) {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      refresh()
    } catch {
      statusMessage = error.localizedDescription
      refresh(keepingMessage: true)
    }
  }

  private func refresh(keepingMessage: Bool = false) {
    let status = SMAppService.mainApp.status
    isEnabled = status == .enabled || status == .requiresApproval
    if keepingMessage { return }

    switch status {
    case .enabled:
      statusMessage = "FreeThumb will launch after you sign in."
    case .requiresApproval:
      statusMessage = "Approve FreeThumb in System Settings > General > Login Items."
    case .notRegistered:
      statusMessage = "FreeThumb will not launch automatically."
    case .notFound:
      statusMessage = "Move FreeThumb to Applications before enabling launch at login."
    @unknown default:
      statusMessage = "Login item status is unavailable."
    }
  }
}
