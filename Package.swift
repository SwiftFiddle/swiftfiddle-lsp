// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "swiftfiddle-lsp",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.76.2"),
        .package(url: "https://github.com/apple/sourcekit-lsp", branch: "main")
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "LSPBindings", package: "sourcekit-lsp"),
            ],
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .executableTarget(name: "Run", dependencies: [.target(name: "App")]),
    ]
)
