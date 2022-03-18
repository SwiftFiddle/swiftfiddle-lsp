// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "formatter",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-format.git", from: "0.50600.0"),
    ]
)
