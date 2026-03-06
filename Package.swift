// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "macos-mcp-server",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "macos-mcp-server", targets: ["MacOSMCPServer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.11.0"),
    ],
    targets: [
        .executableTarget(
            name: "MacOSMCPServer",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
            ]
        ),
    ]
)
