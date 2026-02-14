// swift-tools-version: 5.9
// Rockit Language Compiler
// Dark Matter Tech — Codename Mars

import PackageDescription

let package = Package(
    name: "RockitCompiler",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "rockit", targets: ["RockitCLI"]),
        .library(name: "RockitKit", targets: ["RockitKit"]),
    ],
    targets: [
        // Core compiler library
        .target(
            name: "RockitKit",
            path: "Sources/RockitKit"
        ),
        // CLI entry point
        .executableTarget(
            name: "RockitCLI",
            dependencies: ["RockitKit"],
            path: "Sources/RockitCLI"
        ),
        // Tests
        .testTarget(
            name: "RockitKitTests",
            dependencies: ["RockitKit"],
            path: "Tests/RockitKitTests"
        ),
    ]
)
