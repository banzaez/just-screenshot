// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "JustScreenshotApp",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "JustScreenshotApp"
        ),
        .testTarget(
            name: "JustScreenshotAppTests",
            dependencies: ["JustScreenshotApp"]
        ),
    ]
)
