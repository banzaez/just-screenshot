// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "JustScreenshotApp",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
        .package(url: "https://github.com/awxkee/webp.swift.git", from: "1.1.2")
    ],
    targets: [
        .executableTarget(
            name: "JustScreenshotApp",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "webp", package: "webp.swift")
            ]
        ),
        .testTarget(
            name: "JustScreenshotAppTests",
            dependencies: ["JustScreenshotApp"]
        ),
    ]
)
