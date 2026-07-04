import Testing

@testable import FreeThumbCore

struct VersionComparisonTests {
  @Test func comparesNumericVersionComponents() {
    #expect(VersionComparison.isNewer("1.10.0", than: "1.9.9"))
    #expect(!VersionComparison.isNewer("1.2.0", than: "1.2.0"))
    #expect(!VersionComparison.isNewer("1.1.9", than: "1.2.0"))
  }
}
