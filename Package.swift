// swift-tools-version:6.1

import PackageDescription

let package = Package(
    name: "XCLineFramework",
    platforms: [
        .macOS(.v10_15),
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
