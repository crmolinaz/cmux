// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CmuxMascot",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CmuxMascot",
            targets: ["CmuxMascot"]
        ),
    ],
    targets: [
        .target(
            name: "CmuxMascot",
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CmuxMascotTests",
            dependencies: ["CmuxMascot"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
