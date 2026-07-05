// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "FreeThumb",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .library(name: "FreeThumbCore", targets: ["FreeThumbCore"]),
    .library(name: "FreeThumbMac", targets: ["FreeThumbMac"]),
    .executable(name: "freethumb", targets: ["FreeThumbCLI"]),
    .executable(name: "FreeThumb", targets: ["FreeThumbApp"]),
  ],
  targets: [
    .target(name: "FreeThumbCore"),
    .target(
      name: "FreeThumbMac",
      dependencies: ["FreeThumbCore"],
      linkerSettings: [
        .linkedFramework("IOKit")
      ]
    ),
    .executableTarget(
      name: "FreeThumbCLI",
      dependencies: ["FreeThumbCore", "FreeThumbMac"]
    ),
    .executableTarget(
      name: "FreeThumbApp",
      dependencies: ["FreeThumbCore", "FreeThumbMac"]
    ),
    .testTarget(
      name: "FreeThumbCoreTests",
      dependencies: ["FreeThumbCore"]
    ),
  ]
)
