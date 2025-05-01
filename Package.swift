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
        .package(url: "https://github.com/swiftlang/swift-syntax", "509.0.0"..<"602.0.0"),
    ],
    targets: [
        .target(
            name: "XCLineFramework",
            dependencies: [
                .product(name: "SourceKittenFramework", package: "SourceKitten"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftOperators", package: "swift-syntax"),
                .product(name: "SwiftParserDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
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
