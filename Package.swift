// swift-tools-version:6.1

import PackageDescription

let package = Package(
    name: "XCLineFramework",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "XCLineFramework",
            targets: ["XCLineFramework"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/SourceKitten.git", .upToNextMajor(from: "0.37.0")),
    ],
    targets: [
        .target(
            name: "XCLineFramework",
            dependencies: [
                .product(name: "SourceKittenFramework", package: "SourceKitten"),
            ]
        ),
        .testTarget(
            name: "XCLineFrameworkTests",
            dependencies: [
                "XCLineFramework"
            ]
        )
    ]
)
