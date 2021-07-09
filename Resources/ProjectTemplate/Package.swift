// swift-tools-version:5.4
import PackageDescription

let package = Package(
    name: "_Workspace",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "_Workspace", type: .dynamic, targets: ["_Workspace"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-algorithms", from: "0.2.1"),
        .package(url: "https://github.com/apple/swift-atomics", from: "0.0.3"),
        .package(url: "https://github.com/apple/swift-collections", from: "0.0.4"),
        .package(url: "https://github.com/apple/swift-crypto", from: "1.1.6"),
        .package(url: "https://github.com/apple/swift-numerics", from: "0.1.0"),
        .package(url: "https://github.com/apple/swift-system", from: "0.0.2"),
    ],
    targets: [
        .executableTarget(
            name: "_Workspace",
            dependencies: [
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "Atomics", package: "swift-atomics"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Numerics", package: "swift-numerics"),
                .product(name: "SystemPackage", package: "swift-system"),
            ]
        ),
    ]
)
