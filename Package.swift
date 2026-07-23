// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Unhog",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "CulpritCore", targets: ["CulpritCore"]),
        .executable(name: "Unhog", targets: ["Culprit"])
    ],
    targets: [
        .target(name: "CulpritCore"),
        .executableTarget(
            name: "Culprit",
            dependencies: ["CulpritCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "CulpritCoreTests",
            dependencies: ["CulpritCore"]
        )
    ]
)
