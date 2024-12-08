// swift-tools-version: 5.7

import PackageDescription
import Foundation

let package = Package(
  name: "Plugins",
  products: [
    .library(
      name: "Plugins",
      targets: ["Plugins"]),
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "Plugins",
      dependencies: [],
      swiftSettings: [],
      linkerSettings: [
        .linkedLibrary("dl", .when(platforms: [.linux]))
      ]
    ),
    .testTarget(
      name: "PluginsTests",
      dependencies: [
        "Plugins",
      ],
      swiftSettings: []
    )
  ]
)

let env = ProcessInfo.processInfo.environment
let pluginsTargetIndex = package.targets.firstIndex(where: { target in target.name == "Plugins" })!
let pluginsTestsTargetIndex = package.targets.firstIndex(where: { target in target.name == "PluginsTests" })!
if env["SWIFTPLUGINS_NO_LOGGING"] == nil {
  package.dependencies.append(.package(url: "https://github.com/apple/swift-log", from: "1.0.0"))
  package.targets[pluginsTargetIndex].dependencies.append(.product(name: "Logging", package: "swift-log"))
  package.targets[pluginsTestsTargetIndex].dependencies.append(.product(name: "Logging", package: "swift-log"))
} else {
  package.targets[pluginsTargetIndex].swiftSettings!.append(.define("SWIFTPLUGINS_NO_LOGGING"))
  package.targets[pluginsTestsTargetIndex].swiftSettings!.append(.define("SWIFTPLUGINS_NO_LOGGING"))
}
