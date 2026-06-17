// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DontStop",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "DontStopCore", targets: ["DontStopCore"])
    ],
    targets: [
        .target(
            name: "DontStopCore",
            path: "Sources/DontStopCore"
        ),
        .testTarget(
            name: "DontStopCoreTests",
            dependencies: ["DontStopCore"],
            path: "Tests/DontStopCoreTests"
        )
    ]
)
