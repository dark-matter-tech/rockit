// swift-tools-version: 5.9
// Moon Language Compiler
// Dark Matter Tech — Codename Mars

import PackageDescription

let package = Package(
    name: "MoonCompiler",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "moonc", targets: ["MoonCLI"]),
        .library(name: "MoonKit", targets: ["MoonKit"]),
    ],
    targets: [
        // Core compiler library
        .target(
            name: "MoonKit",
            path: "Sources/MoonKit"
        ),
        // CLI entry point
        .executableTarget(
            name: "MoonCLI",
            dependencies: ["MoonKit"],
            path: "Sources/MoonCLI"
        ),
        // Tests
        .testTarget(
            name: "MoonKitTests",
            dependencies: ["MoonKit"],
            path: "Tests/MoonKitTests"
        ),
    ]
)
