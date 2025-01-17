// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-systemd",
    platforms: [
        .iOS(.v13),
        .macOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(name: "Systemd", targets: ["Systemd"]),
        .library(name: "SystemdLifecycle", targets: ["SystemdLifecycle"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.1.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.6.2"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.3.0"),
    ],
    targets: [
        .systemLibrary(
            name: "CSystemd",
            providers: [
                .apt(["libsystemd-dev"]),
                .yum(["systemd-devel"]),
            ]
        ),
        .target(
            name: "Systemd",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                "CSystemd",
            ]
        ),
        .target(
            name: "SystemdLifecycle",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                "Systemd",
            ]
        ),
        .executableTarget(
            name: "Example",
            dependencies: ["SystemdLifecycle"],
            exclude: ["example-systemd.service"]
        ),
    ]
)
