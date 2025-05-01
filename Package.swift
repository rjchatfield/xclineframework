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
    targets: [
        .target(
            name: "XCLineFramework"
        ),
        .testTarget(
            name: "XCLineFrameworkTests",
            dependencies: [
                "XCLineFramework"
            ]
        )
    ]
)
