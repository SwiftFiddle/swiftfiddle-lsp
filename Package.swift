// swift-tools-version:5.8
import PackageDescription

let package = Package(
  name: "swiftfiddle-lsp",
  platforms: [
    .macOS(.v12)
  ],
  dependencies: [
    .package(url: "https://github.com/vapor/vapor.git", from: "4.83.2"),
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
