import Darwin
import Foundation

actor HighActivityAppMonitor {
  private var previousSamples: [Int32: ProcessSample] = [:]
  private var previousSampleDate: Date?

  func sample() async -> [HighActivityApp] {
    var currentDate = Date()
    var currentSamples = await readProcessSamples()

    if previousSampleDate == nil {
      previousSamples = Dictionary(uniqueKeysWithValues: currentSamples.map { ($0.processID, $0) })
      previousSampleDate = currentDate
      try? await Task.sleep(for: .seconds(1))
      guard !Task.isCancelled else { return [] }
      currentDate = Date()
      currentSamples = await readProcessSamples()
    }

    guard let previousSampleDate else { return [] }
    let elapsedSeconds = max(currentDate.timeIntervalSince(previousSampleDate), 0.001)
    let results = rankedApps(from: currentSamples, elapsedSeconds: elapsedSeconds)

    previousSamples = Dictionary(uniqueKeysWithValues: currentSamples.map { ($0.processID, $0) })
    self.previousSampleDate = currentDate
    return Array(results.prefix(5))
  }

  private func readProcessSamples() async -> [ProcessSample] {
    await Task.detached(priority: .utility) {
      Self.readProcessSamples()
    }.value
  }

  private func rankedApps(
    from currentSamples: [ProcessSample],
    elapsedSeconds: TimeInterval
  ) -> [HighActivityApp] {
    let grouped = Dictionary(grouping: currentSamples, by: \.bundlePath)
    let apps = grouped.compactMap { bundlePath, processes -> HighActivityApp? in
      guard let processID = processes.first?.processID else { return nil }
      let energyNanojoules = processes.reduce(UInt64(0)) { total, process in
        guard let previous = previousSamples[process.processID],
          process.energyNanojoules >= previous.energyNanojoules
        else { return total }
        return total + process.energyNanojoules - previous.energyNanojoules
      }
      let powerWatts = Double(energyNanojoules) / elapsedSeconds / 1_000_000_000
      let cpuPercent = processes.reduce(0) { $0 + $1.cpuPercent }
      guard powerWatts >= 0.01 || cpuPercent >= 0.5 else { return nil }

      return HighActivityApp(
        processID: processID,
        name: URL(fileURLWithPath: bundlePath).deletingPathExtension().lastPathComponent,
        powerWatts: energyNanojoules > 0 ? powerWatts : nil,
        cpuPercent: cpuPercent,
        memoryBytes: processes.reduce(0) { $0 + $1.memoryBytes }
      )
    }

    return apps.sorted {
      switch ($0.powerWatts, $1.powerWatts) {
      case (let left?, let right?) where left != right: return left > right
      case (_?, nil): return true
      case (nil, _?): return false
      default:
        if $0.cpuPercent == $1.cpuPercent { return $0.memoryBytes > $1.memoryBytes }
        return $0.cpuPercent > $1.cpuPercent
      }
    }
  }

  private static func readProcessSamples() -> [ProcessSample] {
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

      return text.split(separator: "\n").compactMap { parse(String($0)) }
    } catch {
      return []
    }
  }

  private static func parse(_ line: String) -> ProcessSample? {
    let fields = line.split(maxSplits: 4, whereSeparator: { $0.isWhitespace })
    guard fields.count == 5,
      let processID = Int32(fields[0]),
      let userID = uid_t(fields[1]),
      userID == getuid(),
      let cpuPercent = Double(fields[2]),
      let residentKilobytes = UInt64(fields[3]),
      let bundlePath = appBundlePath(from: String(fields[4])),
      isThirdPartyApp(at: bundlePath),
      bundlePath != Bundle.main.bundlePath
    else { return nil }

    return ProcessSample(
      processID: processID,
      bundlePath: bundlePath,
      energyNanojoules: energyNanojoules(for: processID) ?? 0,
      cpuPercent: cpuPercent,
      memoryBytes: residentKilobytes * 1_024
    )
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

  private static func energyNanojoules(for processID: Int32) -> UInt64? {
    var usage = rusage_info_v6()
    let result = withUnsafeMutablePointer(to: &usage) { pointer in
      let buffer = UnsafeMutableRawPointer(pointer).assumingMemoryBound(to: rusage_info_t?.self)
      return proc_pid_rusage(processID, RUSAGE_INFO_V6, buffer)
    }
    guard result == 0 else { return nil }
    return usage.ri_energy_nj
  }
}

private struct ProcessSample: Sendable {
  let processID: Int32
  let bundlePath: String
  let energyNanojoules: UInt64
  let cpuPercent: Double
  let memoryBytes: UInt64
}
