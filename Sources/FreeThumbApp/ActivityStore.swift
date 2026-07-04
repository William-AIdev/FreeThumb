import Combine
import FreeThumbCore

@MainActor
final class ActivityStore: ObservableObject {
  @Published private(set) var tracker = SessionActivityTracker()
  @Published private(set) var isEnabled: Bool

  init(isEnabled: Bool) {
    self.isEnabled = isEnabled
  }

  func setEnabled(_ enabled: Bool) {
    isEnabled = enabled
  }

  func replaceTracker(_ tracker: SessionActivityTracker) {
    self.tracker = tracker
  }
}
