// swift-tools-version: 5.9
// Rockit Language Compiler
// Dark Matter Tech — Codename Mars

import PackageDescription

let package = Package(
    name: "RockitCompiler",
    // platforms is only meaningful for Apple targets.
    // On Linux and Windows, SPM ignores this field.
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "rockit", targets: ["RockitCLI"]),
        .library(name: "RockitKit", targets: ["RockitKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    ],
    targets: [
        // OpenSSL C interop for Linux
        .systemLibrary(
            name: "COpenSSL",
            path: "bootstrap-swift/COpenSSL",
            pkgConfig: "openssl",
            providers: [.apt(["libssl-dev"])]
        ),
        // Core compiler library
        .target(
            name: "RockitKit",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                .target(name: "COpenSSL", condition: .when(platforms: [.linux])),
            ],
            path: "bootstrap-swift/RockitKit"
        ),
        // Language Server Protocol
        .target(
            name: "RockitLSP",
            dependencies: ["RockitKit"],
            path: "lsp/RockitLSP"
        ),
        // CLI entry point
        .executableTarget(
            name: "RockitCLI",
            dependencies: ["RockitKit", "RockitLSP"],
            path: "bootstrap-swift/RockitCLI"
        ),
        // Tests
        .testTarget(
            name: "RockitKitTests",
            dependencies: ["RockitKit"],
            path: "bootstrap-swift/Tests/RockitKitTests"
        ),
    ]
)
