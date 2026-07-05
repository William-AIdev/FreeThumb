import CoreFoundation
import IOKit.ps

@MainActor
public final class PowerSourceEventMonitor {
  private var notificationSource: CFRunLoopSource?
  private var onChange: (() -> Void)?

  public init() {}

  public func start(onChange: @escaping () -> Void) {
    stop()
    self.onChange = onChange

    let context = Unmanaged.passUnretained(self).toOpaque()
    guard
      let source = IOPSNotificationCreateRunLoopSource(
        { context in
          guard let context else { return }
          let monitor = Unmanaged<PowerSourceEventMonitor>
            .fromOpaque(context)
            .takeUnretainedValue()
          Task { @MainActor in
            monitor.onChange?()
          }
        },
        context
      )?.takeRetainedValue()
    else { return }

    notificationSource = source
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
  }

  public func stop() {
    if let notificationSource {
      CFRunLoopSourceInvalidate(notificationSource)
    }
    notificationSource = nil
    onChange = nil
  }
}
