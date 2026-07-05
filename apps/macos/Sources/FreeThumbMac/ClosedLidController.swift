import Foundation

public actor ClosedLidController {
  private var previousSleepDisabled: Bool?
  private var watchdog: Process?

  public init() {}

  public func enable() throws -> ClosedLidActivation {
    if let previousSleepDisabled {
      return ClosedLidActivation(modifiedSystemSetting: !previousSleepDisabled)
    }

    let previousValue = Self.isSleepDisabled()
    guard !previousValue else {
      previousSleepDisabled = true
      return ClosedLidActivation(modifiedSystemSetting: false)
    }

    do {
      if !Self.trySetSleepDisabled(true) {
        try Self.installScopedAuthorization()
        try Self.setSleepDisabled(true)
      }

      guard Self.isSleepDisabled() else {
        throw ClosedLidError.verificationFailed
      }

      watchdog = try Self.startWatchdog(
        parentPID: ProcessInfo.processInfo.processIdentifier,
        restoreValue: false
      )
      previousSleepDisabled = false
      return ClosedLidActivation(modifiedSystemSetting: true)
    } catch {
      _ = Self.trySetSleepDisabled(false)
      throw error
    }
  }

  public func disable() throws {
    guard let previousSleepDisabled else { return }

    if !previousSleepDisabled {
      try Self.setSleepDisabled(false)
      guard !Self.isSleepDisabled() else {
        throw ClosedLidError.verificationFailed
      }
    }

    stopWatchdog()
    self.previousSleepDisabled = nil
  }

  public nonisolated static func isSleepDisabled() -> Bool {
    guard
      let result = try? run(
        "/usr/sbin/ioreg",
        arguments: ["-r", "-k", "SleepDisabled"]
      )
    else {
      return false
    }
    return result.stdout.contains(#""SleepDisabled" = Yes"#)
  }

  public nonisolated static func needsAdministratorAuthorization() -> Bool {
    for value in ["0", "1"] {
      guard
        let result = try? run(
          "/usr/bin/sudo",
          arguments: ["-n", "-l", "/usr/bin/pmset", "disablesleep", value]
        ),
        result.exitCode == 0
      else {
        return true
      }
    }
    return false
  }

  private func stopWatchdog() {
    guard let watchdog else { return }
    if watchdog.isRunning {
      watchdog.terminate()
      watchdog.waitUntilExit()
    }
    self.watchdog = nil
  }

  private static func trySetSleepDisabled(_ disabled: Bool) -> Bool {
    do {
      try setSleepDisabled(disabled)
      return true
    } catch {
      return false
    }
  }

  private static func setSleepDisabled(_ disabled: Bool) throws {
    let result = try run(
      "/usr/bin/sudo",
      arguments: [
        "-n",
        "/usr/bin/pmset",
        "disablesleep",
        disabled ? "1" : "0",
      ]
    )
    guard result.exitCode == 0 else {
      throw ClosedLidError.commandFailed(result.failureMessage)
    }
  }

  private static func installScopedAuthorization() throws {
    let userName = NSUserName()
    let allowedCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"
    guard !userName.isEmpty, userName.allSatisfy(allowedCharacters.contains) else {
      throw ClosedLidError.unsupportedUserName
    }

    let destination = "/private/etc/sudoers.d/freethumb"
    let temporary = "/private/tmp/freethumb-sudoers-\(ProcessInfo.processInfo.processIdentifier)"
    let contents =
      "# FreeThumb closed-lid mode permission\n"
      + "\(userName) ALL=(root) NOPASSWD: /usr/bin/pmset disablesleep 0, "
      + "/usr/bin/pmset disablesleep 1\n"

    let command = [
      "/bin/mkdir -p /private/etc/sudoers.d",
      "/usr/bin/printf %s \(shellQuoted(contents)) > \(shellQuoted(temporary))",
      "/usr/sbin/visudo -cf \(shellQuoted(temporary)) >/dev/null",
      "/usr/sbin/chown root:wheel \(shellQuoted(temporary))",
      "/bin/chmod 440 \(shellQuoted(temporary))",
      "/bin/mv \(shellQuoted(temporary)) \(shellQuoted(destination))",
    ].joined(separator: " && ")

    let script = "do shell script \(appleScriptLiteral(command)) with administrator privileges"
    let result = try run("/usr/bin/osascript", arguments: ["-e", script])
    guard result.exitCode == 0 else {
      if result.stderr.localizedCaseInsensitiveContains("user canceled") {
        throw ClosedLidError.authorizationCancelled
      }
      throw ClosedLidError.authorizationFailed(result.failureMessage)
    }
  }

  private static func startWatchdog(parentPID: Int32, restoreValue: Bool) throws -> Process {
    let value = restoreValue ? "1" : "0"
    let script = """
      while /bin/kill -0 \(parentPID) 2>/dev/null; do /bin/sleep 2; done
      /usr/bin/sudo -n /usr/bin/pmset disablesleep \(value)
      """

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", script]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    return process
  }

  private nonisolated static func run(
    _ executable: String,
    arguments: [String]
  ) throws -> CommandResult {
    let process = Process()
    let standardOutput = Pipe()
    let standardError = Pipe()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = standardOutput
    process.standardError = standardError

    try process.run()
    process.waitUntilExit()

    return CommandResult(
      exitCode: process.terminationStatus,
      stdout: String(
        decoding: standardOutput.fileHandleForReading.readDataToEndOfFile(),
        as: UTF8.self
      ),
      stderr: String(
        decoding: standardError.fileHandleForReading.readDataToEndOfFile(),
        as: UTF8.self
      )
    )
  }

  private static func shellQuoted(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
  }

  private static func appleScriptLiteral(_ value: String) -> String {
    let escaped =
      value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(escaped)\""
  }
}

public struct ClosedLidActivation: Sendable {
  public let modifiedSystemSetting: Bool
}

public enum ClosedLidError: Error, CustomStringConvertible {
  case authorizationCancelled
  case authorizationFailed(String)
  case commandFailed(String)
  case unsupportedUserName
  case verificationFailed

  public var description: String {
    switch self {
    case .authorizationCancelled:
      "Administrator authorization was cancelled"
    case .authorizationFailed(let message):
      "Unable to install closed-lid permission: \(message)"
    case .commandFailed(let message):
      "Unable to change the macOS sleep setting: \(message)"
    case .unsupportedUserName:
      "This macOS user name is not supported"
    case .verificationFailed:
      "macOS did not apply the requested sleep setting"
    }
  }
}

private struct CommandResult {
  let exitCode: Int32
  let stdout: String
  let stderr: String

  var failureMessage: String {
    let message = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
    return message.isEmpty ? "command exited with status \(exitCode)" : message
  }
}
