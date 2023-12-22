// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-systemd",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Systemd",
            targets: ["Systemd"]),
    ],
    targets: [
        .systemLibrary(name: "CSystemd"),
        .target(
            name: "Systemd",
            dependencies: [
                "CSystemd"
            ]
        ),
        .executableTarget(
            name: "Example",
            dependencies: [
                "Systemd"
            ],
            exclude: [ "example-systemd-service.service" ]
        )
    ]
)
