// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Culprit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "CulpritCore", targets: ["CulpritCore"]),
        .executable(name: "Culprit", targets: ["Culprit"])
    ],
    targets: [
        .target(name: "CulpritCore"),
        .executableTarget(
            name: "Culprit",
            dependencies: ["CulpritCore"]
        ),
        .testTarget(
            name: "CulpritCoreTests",
            dependencies: ["CulpritCore"]
        )
    ]
)
