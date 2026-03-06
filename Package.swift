// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClaudeConfigKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "ClaudeConfigKit", targets: ["ClaudeConfigKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
    ],
    targets: [
        .target(
            name: "ClaudeConfigKit",
            dependencies: [.product(name: "Logging", package: "swift-log")]
        ),
        .testTarget(
            name: "ClaudeConfigKitTests",
            dependencies: ["ClaudeConfigKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
