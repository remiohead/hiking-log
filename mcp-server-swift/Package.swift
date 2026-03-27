// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HikingMCPServer",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.11.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "HikingMCPServer",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
            ],
            path: "Sources"
        )
    ]
)
