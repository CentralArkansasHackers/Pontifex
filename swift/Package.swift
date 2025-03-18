// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Pontifex",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "pontifex", targets: ["Pontifex"])
    ],
    targets: [
        .target(
            name: "Pontifex",
            dependencies: []
        )
    ]
)

