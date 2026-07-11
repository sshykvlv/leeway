// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LimitBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "LimitBar", path: "Sources/LimitBar"),
        .testTarget(name: "LimitBarTests", dependencies: ["LimitBar"],
                    path: "Tests/LimitBarTests",
                    resources: [.copy("Fixtures")]),
    ]
)
