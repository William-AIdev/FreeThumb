import Foundation
import FreeThumbCore
import FreeThumbMac

enum CommandError: Error, CustomStringConvertible {
  case invalidArguments(String)

  var description: String {
    switch self {
    case .invalidArguments(let message): message
    }
  }
}

@main
struct FreeThumbCLI {
  static func main() async {
    do {
      try await run(arguments: Array(CommandLine.arguments.dropFirst()))
    } catch {
      FileHandle.standardError.write(Data("Error: \(error)\n".utf8))
      Foundation.exit(EXIT_FAILURE)
    }
  }

  private static func run(arguments: [String]) async throws {
    guard let command = arguments.first else {
      printUsage()
      return
    }

    switch command {
    case "status":
      try printStatus(asJSON: arguments.dropFirst().contains("--json"))
    case "protect":
      let minutes = try parseMinutes(arguments: Array(arguments.dropFirst()))
      try await protect(minutes: minutes)
    case "help", "--help", "-h":
      printUsage()
    default:
      throw CommandError.invalidArguments("Unknown command: \(command)")
    }
  }

  private static func printStatus(asJSON: Bool) throws {
    let snapshot = MacSystemMonitor().snapshot()
    if asJSON {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      print(String(decoding: try encoder.encode(snapshot), as: UTF8.self))
    } else {
      print(describe(snapshot))
    }
  }

  private static func protect(minutes: Int) async throws {
    let duration = TimeInterval(minutes * 60)
    let assertion = SleepAssertion()
    try assertion.start(duration: duration)
    defer { assertion.stop() }

    let monitor = MacSystemMonitor()
    let policy = ProtectionPolicy()
    let end = Date().addingTimeInterval(duration)

    print("FreeThumb protection active for \(minutes) minute(s). Press Ctrl-C to stop.")

    while Date() < end {
      let snapshot = monitor.snapshot()
      let decision = policy.evaluate(snapshot)
      print("[\(timestamp())] \(describe(snapshot))")

      switch decision {
      case .continueRunning:
        break
      case .warn(let reason):
        print("Warning: \(reason)")
      }

      let remaining = end.timeIntervalSinceNow
      if remaining > 0 {
        try await Task.sleep(for: .seconds(min(15, remaining)))
      }
    }

    print("Protection ended: session timer expired.")
  }

  private static func parseMinutes(arguments: [String]) throws -> Int {
    guard !arguments.isEmpty else { return 120 }
    guard arguments.count == 2,
      arguments[0] == "--minutes",
      let minutes = Int(arguments[1]),
      (1...720).contains(minutes)
    else {
      throw CommandError.invalidArguments("Use --minutes with a value from 1 to 720")
    }
    return minutes
  }

  private static func describe(_ snapshot: SystemSnapshot) -> String {
    let battery = snapshot.batteryPercent.map { "\($0)%" } ?? "unknown"
    return "power=\(snapshot.powerSource.rawValue) battery=\(battery) "
      + "thermal=\(snapshot.thermalLevel.rawValue) lowPowerMode=\(snapshot.lowPowerModeEnabled)"
  }

  private static func timestamp() -> String {
    Date().formatted(date: .omitted, time: .standard)
  }

  private static func printUsage() {
    print(
      """
      FreeThumb macOS feasibility prototype

      Usage:
        freethumb status [--json]
        freethumb protect [--minutes 1...720]
      """)
  }
}
