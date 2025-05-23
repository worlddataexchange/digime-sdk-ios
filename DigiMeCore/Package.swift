// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DigiMeCore",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(name: "DigiMeCore", targets: ["DigiMeCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", branch: "main"),
    ],
    targets: [
        .target(
            name: "DigiMeCore",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("Security"),
                .linkedFramework("CryptoKit")
            ]),
    ]
)
