import Foundation
import IOKit.pwr_mgt

public final class SleepAssertion {
  private var assertionID: IOPMAssertionID?

  public init() {}

  public func start(duration: TimeInterval) throws {
    guard assertionID == nil else { return }

    var newAssertionID: IOPMAssertionID = 0
    let result = IOPMAssertionCreateWithDescription(
      kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
      "FreeThumb AI Work Mode" as CFString,
      "Keeps local AI coding tasks running for a bounded session" as CFString,
      nil,
      nil,
      duration,
      kIOPMAssertionTimeoutActionTurnOff as CFString,
      &newAssertionID
    )

    guard result == kIOReturnSuccess else {
      throw SleepAssertionError.creationFailed(code: result)
    }

    assertionID = newAssertionID
  }

  public func stop() {
    guard let assertionID else { return }
    IOPMAssertionRelease(assertionID)
    self.assertionID = nil
  }

  deinit {
    stop()
  }
}

public enum SleepAssertionError: Error, CustomStringConvertible {
  case creationFailed(code: IOReturn)

  public var description: String {
    switch self {
    case .creationFailed(let code):
      "Unable to create macOS power assertion (IOKit code \(code))"
    }
  }
}
