// swift-tools-version: 5.7

import PackageDescription

let package = Package(
  name: "PluginManager",
  products: [
    .library(
      name: "Plugins",
      targets: ["Plugins"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-log", from: "1.0.0")
  ],
  targets: [
    .target(
      name: "Plugins",
      dependencies: [
        .product(name: "Logging", package: "swift-log")
      ]
    ),
    .testTarget(
      name: "PluginsTests",
      dependencies: [
        "Plugins",
        .product(name: "Logging", package: "swift-log")
      ]
    )
  ]
)