// SemanticVersion.swift
// RockitKit — Rockit Language Compiler
// Copyright © 2026 Dark Matter Tech. All rights reserved.

import Foundation

/// A semantic version: MAJOR.MINOR.PATCH
public struct SemanticVersion: Comparable, Hashable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// Parse a version string like "1.2.3" or "v1.2.3"
    public init?(parsing string: String) {
        var s = string.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("v") || s.hasPrefix("V") {
            s = String(s.dropFirst())
        }
        let parts = s.split(separator: ".")
        guard parts.count == 3,
              let major = Int(parts[0]),
              let minor = Int(parts[1]),
              let patch = Int(parts[2]),
              major >= 0, minor >= 0, patch >= 0 else {
            return nil
        }
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public var description: String {
        "\(major).\(minor).\(patch)"
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}

/// A version constraint that can be checked against a SemanticVersion
public struct VersionConstraint: CustomStringConvertible {
    public enum Kind {
        case exact(SemanticVersion)         // "1.2.3"
        case caret(SemanticVersion)         // "^1.2.3" — >=1.2.3, <2.0.0
        case tilde(SemanticVersion)         // "~1.2.3" — >=1.2.3, <1.3.0
        case greaterOrEqual(SemanticVersion) // ">=1.2.3"
        case any                            // "*"
    }

    public let kind: Kind

    public init(kind: Kind) {
        self.kind = kind
    }

    /// Parse a constraint string like "^1.0.0", "~2.1.3", ">=1.0.0", "1.2.3", or "*"
    public init?(parsing string: String) {
        let s = string.trimmingCharacters(in: .whitespaces)
        if s == "*" {
            self.kind = .any
        } else if s.hasPrefix("^") {
            guard let v = SemanticVersion(parsing: String(s.dropFirst())) else { return nil }
            self.kind = .caret(v)
        } else if s.hasPrefix("~") {
            guard let v = SemanticVersion(parsing: String(s.dropFirst())) else { return nil }
            self.kind = .tilde(v)
        } else if s.hasPrefix(">=") {
            guard let v = SemanticVersion(parsing: String(s.dropFirst(2))) else { return nil }
            self.kind = .greaterOrEqual(v)
        } else {
            guard let v = SemanticVersion(parsing: s) else { return nil }
            self.kind = .exact(v)
        }
    }

    /// Check if a given version satisfies this constraint
    public func satisfiedBy(_ version: SemanticVersion) -> Bool {
        switch kind {
        case .any:
            return true
        case .exact(let v):
            return version == v
        case .caret(let v):
            // >=v, <nextMajor
            guard version >= v else { return false }
            if v.major == 0 {
                // ^0.x.y is special: >=0.x.y, <0.(x+1).0
                return version.major == 0 && version.minor == v.minor && version.patch >= v.patch
            }
            return version.major == v.major
        case .tilde(let v):
            // >=v, <v.major.(v.minor+1).0
            guard version >= v else { return false }
            return version.major == v.major && version.minor == v.minor
        case .greaterOrEqual(let v):
            return version >= v
        }
    }

    /// The highest version from a list that satisfies this constraint, or nil
    public func bestMatch(from versions: [SemanticVersion]) -> SemanticVersion? {
        versions.filter { satisfiedBy($0) }.max()
    }

    public var description: String {
        switch kind {
        case .any: return "*"
        case .exact(let v): return "\(v)"
        case .caret(let v): return "^\(v)"
        case .tilde(let v): return "~\(v)"
        case .greaterOrEqual(let v): return ">=\(v)"
        }
    }
}
