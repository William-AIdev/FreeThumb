import Foundation
import IOKit

public enum LidState: String, Sendable {
  case open
  case closed
  case unknown
}

public struct LidStateMonitor: Sendable {
  public init() {}

  public func currentState() -> LidState {
    let service = IOServiceGetMatchingService(
      kIOMainPortDefault,
      IOServiceMatching("IOPMrootDomain")
    )
    guard service != IO_OBJECT_NULL else { return .unknown }
    defer { IOObjectRelease(service) }

    guard
      let value = IORegistryEntryCreateCFProperty(
        service,
        "AppleClamshellState" as CFString,
        kCFAllocatorDefault,
        0
      )?.takeRetainedValue() as? Bool
    else {
      return .unknown
    }
    return value ? .closed : .open
  }
}
