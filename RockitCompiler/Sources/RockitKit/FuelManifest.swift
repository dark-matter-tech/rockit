// FuelManifest.swift
// RockitKit — Rockit Language Compiler
// Copyright © 2026 Dark Matter Tech. All rights reserved.

import Foundation

/// Parsed representation of a fuel.toml manifest
public struct FuelManifest {
    public let package: PackageInfo
    public let dependencies: [String: DependencySpec]

    public init(package: PackageInfo, dependencies: [String: DependencySpec]) {
        self.package = package
        self.dependencies = dependencies
    }
}

/// The [package] section of fuel.toml
public struct PackageInfo {
    public let name: String
    public let version: String
    public let description: String?

    public init(name: String, version: String, description: String? = nil) {
        self.name = name
        self.version = version
        self.description = description
    }
}

/// A dependency specification from [dependencies]
public enum DependencySpec {
    /// Simple string form: `json = "^1.0.0"`
    case simple(versionConstraint: String)

    /// Table form: `http = { version = "~2.1", git = "https://..." }`
    case detailed(version: String?, git: String?, path: String?, branch: String?)

    /// The version constraint string, if any
    public var versionString: String? {
        switch self {
        case .simple(let v): return v
        case .detailed(let v, _, _, _): return v
        }
    }

    /// The git URL, if specified
    public var gitURL: String? {
        switch self {
        case .simple: return nil
        case .detailed(_, let git, _, _): return git
        }
    }

    /// The local path, if specified
    public var localPath: String? {
        switch self {
        case .simple: return nil
        case .detailed(_, _, let path, _): return path
        }
    }

    /// The branch name, if specified
    public var branchName: String? {
        switch self {
        case .simple: return nil
        case .detailed(_, _, _, let branch): return branch
        }
    }
}
