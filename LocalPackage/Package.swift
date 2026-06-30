// swift-tools-version: 6.2

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
]

let package = Package(
    name: "LocalPackage",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .library(
            name: "DataSource",
            targets: ["DataSource"]
        ),
        .library(
            name: "Model",
            targets: ["Model"]
        ),
        .library(
            name: "UserInterface",
            targets: ["UserInterface"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms.git", exact: "1.1.5"),
        .package(url: "https://github.com/apple/swift-log.git", exact: "1.14.0"),
        .package(url: "https://github.com/cybozu/LicenseList.git", exact: "2.5.0"),
        .package(url: "https://github.com/Kyome22/AllocatedUnfairLock.git", exact: "1.0.0"),
        .package(url: "https://github.com/Kyome22/SystemInfoKit.git", exact: "7.1.0"),
    ],
    targets: [
        .target(
            name: "DataSource",
            dependencies: [
                .product(name: "AllocatedUnfairLock", package: "AllocatedUnfairLock"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "SystemInfoKit", package: "SystemInfoKit"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "Model",
            dependencies: [
                "DataSource",
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "UserInterface",
            dependencies: [
                "DataSource",
                "Model",
                .product(name: "LicenseList", package: "LicenseList"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "DataSourceTests",
            dependencies: [
                "DataSource"
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "ModelTests",
            dependencies: [
                "Model",
            ],
            resources: [
                .process("Resources"),
            ],
            swiftSettings: swiftSettings
        ),
    ]
)
