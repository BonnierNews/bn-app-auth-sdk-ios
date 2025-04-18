// swift-tools-version: 5.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BNAppAuth",
    platforms: [
        .iOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "BNAppAuth",
            targets: ["BNAppAuth"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/openid/AppAuth-iOS.git", .upToNextMajor(from: "1.3.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "BNAppAuth",
            dependencies: [
                .product(name: "AppAuth", package: "AppAuth-iOS")
            ],
            swiftSettings: [
                .define("PLATFORM_IOS", .when(platforms: [.iOS]))
            ]
        ),
        .testTarget(
            name: "BNAppAuthTests",
            dependencies: ["BNAppAuth"],
            path: "Tests",
            swiftSettings: [
                .define("PLATFORM_IOS", .when(platforms: [.iOS]))
            ]
        ),
    ]
)
