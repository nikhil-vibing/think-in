// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThinkINMCPServer",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "ThinkINMCPServer",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
            ]
        ),
    ]
)
