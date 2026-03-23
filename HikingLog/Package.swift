// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Hiking",
    platforms: [.macOS(.v14), .iOS(.v17)],
    targets: [
        .executableTarget(
            name: "Hiking",
            path: "HikingLog",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
