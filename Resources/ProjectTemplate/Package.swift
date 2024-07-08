// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "App",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-algorithms", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-atomics", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.1.2"),
        .package(url: "https://github.com/apple/swift-crypto", from: "3.5.2"),
        .package(url: "https://github.com/apple/swift-numerics", from: "1.0.2"),
        .package(url: "https://github.com/apple/swift-system", from: "1.3.1"),
    ],
    targets: [
        .executableTarget(
            name: "App",
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
