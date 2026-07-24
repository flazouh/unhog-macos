// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Unhog",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "UnhogCore", targets: ["UnhogCore"]),
        .executable(name: "Unhog", targets: ["Unhog"])
    ],
    targets: [
        .target(name: "UnhogCore"),
        .executableTarget(
            name: "Unhog",
            dependencies: ["UnhogCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "UnhogCoreTests",
            dependencies: ["UnhogCore"]
        )
    ]
)
