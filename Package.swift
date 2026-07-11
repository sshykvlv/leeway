// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Leeway",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Leeway", path: "Sources/Leeway"),
        .testTarget(name: "LeewayTests", dependencies: ["Leeway"],
                    path: "Tests/LeewayTests",
                    resources: [.copy("Fixtures")]),
    ]
)
