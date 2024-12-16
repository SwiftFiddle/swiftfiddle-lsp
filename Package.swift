// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "swiftfiddle-lsp",
  platforms: [
    .macOS(.v13)
  ],
  dependencies: [
    .package(url: "https://github.com/vapor/vapor.git", from: "4.108.0"),
    .package(url: "https://github.com/apple/sourcekit-lsp", branch: "main")
  ],
  targets: [
    .executableTarget(
      name: "App",
      dependencies: [
        .product(name: "Vapor", package: "vapor"),
        .product(name: "LSPBindings", package: "sourcekit-lsp"),
      ],
      swiftSettings: [
        .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
      ]
    ),
  ]
)
