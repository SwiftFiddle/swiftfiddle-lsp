// swift-tools-version:5.4
import PackageDescription

let package = Package(
    name: "swiftfiddle-lsp",
    platforms: [
        .macOS("10.15.4")
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.55.0"),
        .package(name: "SourceKitLSP", url: "https://github.com/apple/sourcekit-lsp", .branch("main")),
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "LSPBindings", package: "SourceKitLSP"),
            ],
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .executableTarget(name: "Run", dependencies: [.target(name: "App")]),
    ]
)
