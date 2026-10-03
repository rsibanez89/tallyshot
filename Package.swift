// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "TallyShot",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "TallyShotCore"),
        .executableTarget(name: "TallyShot", dependencies: ["TallyShotCore"]),
        .testTarget(name: "TallyShotCoreTests", dependencies: ["TallyShotCore"]),
    ]
)
