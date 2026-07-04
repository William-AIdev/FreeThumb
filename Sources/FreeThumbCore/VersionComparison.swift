import Foundation

public enum VersionComparison {
  public static func isNewer(_ candidate: String, than current: String) -> Bool {
    candidate.compare(current, options: .numeric) == .orderedDescending
  }
}
