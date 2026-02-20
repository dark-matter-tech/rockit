// PackageCache.swift
// RockitKit — Rockit Language Compiler
// Copyright © 2026 Dark Matter Tech. All rights reserved.

import Foundation

/// Manages the local package cache at ~/.rockit/packages/
public class PackageCache {
    public let rootDir: String

    public init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        self.rootDir = (home as NSString).appendingPathComponent(".rockit/packages")
    }

    public init(rootDir: String) {
        self.rootDir = rootDir
    }

    /// Ensure the cache root directory exists
    public func ensureExists() throws {
        try FileManager.default.createDirectory(
            atPath: rootDir,
            withIntermediateDirectories: true
        )
    }

    /// Path for a specific package version: ~/.rockit/packages/<name>-<version>/
    public func packageDir(name: String, version: SemanticVersion) -> String {
        (rootDir as NSString).appendingPathComponent("\(name)-\(version)")
    }

    /// Source directory for a cached package
    public func sourceDir(name: String, version: SemanticVersion) -> String {
        (packageDir(name: name, version: version) as NSString).appendingPathComponent("src")
    }

    /// Check if a package version is already cached
    public func isCached(name: String, version: SemanticVersion) -> Bool {
        let dir = packageDir(name: name, version: version)
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: dir, isDirectory: &isDir) && isDir.boolValue
    }

    /// Path to the fuel.toml inside a cached package
    public func manifestPath(name: String, version: SemanticVersion) -> String {
        (packageDir(name: name, version: version) as NSString).appendingPathComponent("fuel.toml")
    }

    /// Remove a specific cached package version
    public func remove(name: String, version: SemanticVersion) throws {
        let dir = packageDir(name: name, version: version)
        if FileManager.default.fileExists(atPath: dir) {
            try FileManager.default.removeItem(atPath: dir)
        }
    }

    /// Remove all cached packages
    public func clean() throws {
        if FileManager.default.fileExists(atPath: rootDir) {
            try FileManager.default.removeItem(atPath: rootDir)
        }
        try ensureExists()
    }

    /// List all cached packages
    public func listCached() -> [(name: String, version: SemanticVersion)] {
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: rootDir) else {
            return []
        }
        var result: [(String, SemanticVersion)] = []
        for entry in entries {
            // Parse "name-1.2.3" format
            if let dashRange = entry.range(of: "-", options: .backwards) {
                let name = String(entry[entry.startIndex..<dashRange.lowerBound])
                let versionStr = String(entry[dashRange.upperBound...])
                if let version = SemanticVersion(parsing: versionStr) {
                    result.append((name, version))
                }
            }
        }
        return result
    }
}
