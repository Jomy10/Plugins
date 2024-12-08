// swift-tools-version: 5.7

import PackageDescription

let package = Package(
  name: "Plugins",
  products: [
    .library(
      name: "Plugins",
      targets: ["Plugins"]),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "Plugins",
      dependencies: [],
      linkerSettings: [
        .linkedLibrary("dl", .when(platforms: [.linux]))
      ]
    ),
    .testTarget(
      name: "PluginsTests",
      dependencies: [
        "Plugins",
      ]
    )
  ]
)
