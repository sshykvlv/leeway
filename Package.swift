// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AIStatusBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "AIStatusBar", path: "Sources/AIStatusBar"),
        .testTarget(name: "AIStatusBarTests", dependencies: ["AIStatusBar"],
                    path: "Tests/AIStatusBarTests",
                    resources: [.copy("Fixtures")]),
    ]
)
