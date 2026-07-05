import Darwin
import Foundation

actor HighActivityAppMonitor {
  private var runningEstimates: [String: RunningEstimate] = [:]

  func sample() async -> [HighActivityApp] {
    let currentSamples = await readProcessSamples()
    return Array(rankedApps(from: currentSamples).prefix(5))
  }

  private func readProcessSamples() async -> [ProcessSample] {
    await Task.detached(priority: .utility) {
      Self.readProcessSamples()
    }.value
  }

  private func rankedApps(from currentSamples: [ProcessSample]) -> [HighActivityApp] {
    let grouped = Dictionary(grouping: currentSamples, by: \.bundlePath)
    let apps = grouped.compactMap { bundlePath, processes -> HighActivityApp? in
      guard let processID = processes.first?.processID else { return nil }
      let energyImpact = processes.reduce(0) { $0 + $1.energyImpact }
      let cpuPercent = processes.reduce(0) { $0 + $1.cpuPercent }
      guard energyImpact >= 0.1 || cpuPercent >= 0.5 else { return nil }
      var estimate = runningEstimates[bundlePath] ?? RunningEstimate()
      estimate.add(energyImpact)
      runningEstimates[bundlePath] = estimate

      return HighActivityApp(
        processID: processID,
        name: URL(fileURLWithPath: bundlePath).deletingPathExtension().lastPathComponent,
        energyImpact: estimate.average,
        cpuPercent: cpuPercent,
        memoryBytes: processes.reduce(0) { $0 + $1.memoryBytes }
      )
    }

    return apps.sorted {
      if $0.energyImpact == $1.energyImpact { return $0.cpuPercent > $1.cpuPercent }
      return $0.energyImpact > $1.energyImpact
    }
  }

  private static func readProcessSamples() -> [ProcessSample] {
    let activityByProcess = readTopActivity()
    guard !activityByProcess.isEmpty else { return [] }

    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/ps")
    process.arguments = ["-axo", "pid=,uid=,pcpu=,rss=,comm="]
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice

    do {
      try process.run()
      let data = output.fileHandleForReading.readDataToEndOfFile()
      process.waitUntilExit()
      guard process.terminationStatus == 0,
        let text = String(data: data, encoding: .utf8)
      else { return [] }

      return text.split(separator: "\n").compactMap {
        parse(String($0), activityByProcess: activityByProcess)
      }
    } catch {
      return []
    }
  }

  private static func parse(
    _ line: String,
    activityByProcess: [Int32: ProcessActivity]
  ) -> ProcessSample? {
    let fields = line.split(maxSplits: 4, whereSeparator: { $0.isWhitespace })
    guard fields.count == 5,
      let processID = Int32(fields[0]),
      let userID = uid_t(fields[1]),
      userID == getuid(),
      let residentKilobytes = UInt64(fields[3]),
      let bundlePath = appBundlePath(from: String(fields[4])),
      isThirdPartyApp(at: bundlePath),
      bundlePath != Bundle.main.bundlePath,
      let activity = activityByProcess[processID]
    else { return nil }

    return ProcessSample(
      processID: processID,
      bundlePath: bundlePath,
      energyImpact: activity.energyImpact,
      cpuPercent: activity.cpuPercent,
      memoryBytes: residentKilobytes * 1_024
    )
  }

  private static func readTopActivity() -> [Int32: ProcessActivity] {
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/top")
    process.arguments = ["-l", "2", "-n", "100", "-stats", "pid,cpu,power", "-o", "power"]
    var environment = ProcessInfo.processInfo.environment
    environment["LC_ALL"] = "C"
    process.environment = environment
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice

    do {
      try process.run()
      let data = output.fileHandleForReading.readDataToEndOfFile()
      process.waitUntilExit()
      guard process.terminationStatus == 0,
        let text = String(data: data, encoding: .utf8)
      else { return [:] }

      let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
      guard let headerIndex = lines.lastIndex(where: { $0.hasPrefix("PID") }) else { return [:] }
      return Dictionary(
        uniqueKeysWithValues: lines[lines.index(after: headerIndex)...].compactMap {
          parseTopActivity(String($0))
        }
      )
    } catch {
      return [:]
    }
  }

  private static func parseTopActivity(_ line: String) -> (Int32, ProcessActivity)? {
    let fields = line.split(whereSeparator: { $0.isWhitespace })
    guard fields.count == 3,
      let processID = Int32(fields[0]),
      let cpuPercent = Double(fields[1]),
      let energyImpact = Double(fields[2])
    else { return nil }
    return (processID, ProcessActivity(cpuPercent: cpuPercent, energyImpact: energyImpact))
  }

  private static func appBundlePath(from command: String) -> String? {
    guard let appRange = command.range(of: ".app/") else { return nil }
    return String(command[..<appRange.lowerBound]) + ".app"
  }

  private static func isThirdPartyApp(at bundlePath: String) -> Bool {
    let excludedPrefixes = [
      "/System/",
      "/Library/Apple/",
      "/private/var/",
    ]
    guard !excludedPrefixes.contains(where: bundlePath.hasPrefix) else { return false }
    return !(Bundle(path: bundlePath)?.bundleIdentifier?.hasPrefix("com.apple.") ?? false)
  }
}

private struct ProcessSample: Sendable {
  let processID: Int32
  let bundlePath: String
  let energyImpact: Double
  let cpuPercent: Double
  let memoryBytes: UInt64
}

private struct ProcessActivity {
  let cpuPercent: Double
  let energyImpact: Double
}

private struct RunningEstimate {
  private(set) var total = 0.0
  private(set) var sampleCount = 0

  var average: Double {
    sampleCount > 0 ? total / Double(sampleCount) : 0
  }

  mutating func add(_ value: Double) {
    total += value
    sampleCount += 1
  }
}
