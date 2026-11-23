// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "ThoughtsCore",
  platforms: [.macOS("15.4")],
  products: [
    .library(name: "ThoughtsCore", targets: ["ThoughtsCore"]),
    .library(name: "ThoughtsCommands", targets: ["ThoughtsCommands"]),
    .executable(name: "thoughts", targets: ["thoughts"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/apple/swift-argument-parser.git", .upToNextMinor(from: "1.8.2"))
  ],
  targets: [
    .target(name: "ThoughtsCore"),
    .target(
      name: "ThoughtsCommands",
      dependencies: [
        "ThoughtsCore",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .executableTarget(name: "thoughts", dependencies: ["ThoughtsCommands"]),
  ]
)
