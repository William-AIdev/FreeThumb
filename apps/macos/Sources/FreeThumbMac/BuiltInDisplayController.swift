import CoreGraphics
import Darwin
import Foundation

public final class BuiltInDisplayController {
  private typealias GetBrightness =
    @convention(c) (
      CGDirectDisplayID,
      UnsafeMutablePointer<Float>
    ) -> Int32
  private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

  private struct DisplayServices {
    let getBrightness: GetBrightness
    let setBrightness: SetBrightness
  }

  private let services: DisplayServices?
  private var savedBrightness: [CGDirectDisplayID: Float] = [:]

  public init() {
    services = Self.loadDisplayServices()
  }

  public func turnOffBuiltInDisplays() throws {
    guard let services else {
      throw BuiltInDisplayError.controlUnavailable
    }

    let displays = Self.onlineBuiltInDisplays()
    guard !displays.isEmpty else {
      throw BuiltInDisplayError.noBuiltInDisplay
    }

    var changedDisplay = false
    var lastError: BuiltInDisplayError?
    for display in displays {
      var brightness: Float = 0
      let readResult = services.getBrightness(display, &brightness)
      guard readResult == 0 else {
        lastError = .readFailed(code: readResult)
        continue
      }

      if savedBrightness[display] == nil {
        savedBrightness[display] = min(1, max(0, brightness))
      }

      let writeResult = services.setBrightness(display, 0)
      if writeResult == 0 {
        changedDisplay = true
      } else {
        savedBrightness[display] = nil
        lastError = .writeFailed(code: writeResult)
      }
    }

    if !changedDisplay {
      throw lastError ?? .noBuiltInDisplay
    }
  }

  public func restoreBuiltInDisplays() throws {
    guard !savedBrightness.isEmpty else { return }
    guard let services else {
      throw BuiltInDisplayError.controlUnavailable
    }

    var remainingBrightness: [CGDirectDisplayID: Float] = [:]
    var lastError: BuiltInDisplayError?
    for (display, brightness) in savedBrightness {
      let result = services.setBrightness(display, brightness)
      if result != 0 {
        remainingBrightness[display] = brightness
        lastError = .restoreFailed(code: result)
      }
    }
    savedBrightness = remainingBrightness

    if !remainingBrightness.isEmpty {
      throw lastError ?? .controlUnavailable
    }
  }

  private static func onlineBuiltInDisplays() -> [CGDirectDisplayID] {
    let maximumDisplays: UInt32 = 16
    var displays = [CGDirectDisplayID](repeating: 0, count: Int(maximumDisplays))
    var displayCount: UInt32 = 0
    guard CGGetOnlineDisplayList(maximumDisplays, &displays, &displayCount) == .success else {
      return []
    }
    return displays.prefix(Int(displayCount)).filter { CGDisplayIsBuiltin($0) != 0 }
  }

  private static func loadDisplayServices() -> DisplayServices? {
    let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
    guard let handle = dlopen(path, RTLD_LAZY) else { return nil }
    guard
      let getBrightness = dlsym(handle, "DisplayServicesGetBrightness"),
      let setBrightness = dlsym(handle, "DisplayServicesSetBrightness")
    else {
      dlclose(handle)
      return nil
    }

    return DisplayServices(
      getBrightness: unsafeBitCast(getBrightness, to: GetBrightness.self),
      setBrightness: unsafeBitCast(setBrightness, to: SetBrightness.self)
    )
  }
}

public enum BuiltInDisplayError: Error, CustomStringConvertible {
  case controlUnavailable
  case noBuiltInDisplay
  case readFailed(code: Int32)
  case restoreFailed(code: Int32)
  case writeFailed(code: Int32)

  public var description: String {
    switch self {
    case .controlUnavailable:
      "Built-in display control is unavailable on this macOS version"
    case .noBuiltInDisplay:
      "No online built-in display was found"
    case .readFailed(let code):
      "Unable to read built-in display brightness (code \(code))"
    case .restoreFailed(let code):
      "Unable to restore built-in display brightness (code \(code))"
    case .writeFailed(let code):
      "Unable to turn off the built-in display backlight (code \(code))"
    }
  }
}
