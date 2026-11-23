// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "CommentCheck",
  platforms: [.macOS("15.4")],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", .upToNextMinor(from: "604.0.0"))
  ],
  targets: [
    .executableTarget(
      name: "comment-check",
      dependencies: [
        .product(name: "SwiftParser", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
      ]
    ),
    .testTarget(
      name: "CommentCheckTests",
      dependencies: ["comment-check"]
    ),
  ]
)
