// FuelCommands.swift
// RockitCLI — Rockit Language Compiler
// Copyright © 2026 Dark Matter Tech. All rights reserved.

import Foundation
import RockitKit

// MARK: - Dependency Resolution (used by build commands)

/// Resolve Fuel dependencies and return library paths for ImportResolver.
/// Returns empty array if not a Fuel project or no dependencies.
func resolveFuelDependencies() -> [String] {
    let fm = FileManager.default
    let cwd = fm.currentDirectoryPath
    let fuelPath = (cwd as NSString).appendingPathComponent("fuel.toml")

    guard fm.fileExists(atPath: fuelPath) else { return [] }

    let parser = FuelManifestParser()
    guard let manifest = parser.parse(path: fuelPath) else { return [] }
    guard !manifest.dependencies.isEmpty else { return [] }

    let cache = PackageCache()
    do {
        try cache.ensureExists()
    } catch {
        print("warning: could not create package cache: \(error)")
        return []
    }

    let lockPath = (cwd as NSString).appendingPathComponent("fuel.lock")
    let lockFile = FuelLockFile.read(from: lockPath)

    do {
        let resolved = try DependencyResolver(
            manifest: manifest,
            lockFile: lockFile,
            cache: cache
        ).resolve()

        var libPaths: [String] = []
        let fetcher = PackageFetcher(cache: cache)

        for dep in resolved {
            if let localPath = dep.localPath {
                let srcDir = (localPath as NSString).appendingPathComponent("src")
                libPaths.append(srcDir)
            } else if let gitURL = dep.gitURL {
                if !cache.isCached(name: dep.name, version: dep.version) {
                    print("  Fetching \(dep.name) \(dep.version)...")
                    try fetcher.fetch(name: dep.name, gitURL: gitURL, version: dep.version)
                }
                libPaths.append(cache.sourceDir(name: dep.name, version: dep.version))
            }
        }

        // Update lock file
        let newLock = FuelLockFile(packages: resolved.map { dep in
            LockedPackage(
                name: dep.name,
                version: dep.version,
                gitURL: dep.gitURL,
                commitHash: dep.commitHash,
                dependencies: dep.dependencyNames
            )
        })
        if newLock != lockFile {
            try newLock.write(to: lockPath)
        }

        return libPaths
    } catch {
        print("warning: could not resolve dependencies: \(error)")
        return []
    }
}

// MARK: - CLI Commands

/// `rockit fuel install` — resolve and fetch all dependencies
func fuelInstallCommand() {
    let fm = FileManager.default
    let cwd = fm.currentDirectoryPath
    let fuelPath = (cwd as NSString).appendingPathComponent("fuel.toml")

    guard fm.fileExists(atPath: fuelPath) else {
        print("error: no fuel.toml found in current directory")
        exit(1)
    }

    let parser = FuelManifestParser()
    guard let manifest = parser.parse(path: fuelPath) else {
        print("error: could not parse fuel.toml")
        exit(1)
    }

    if manifest.dependencies.isEmpty {
        print("No dependencies to install.")
        return
    }

    let cache = PackageCache()
    do {
        try cache.ensureExists()
    } catch {
        print("error: could not create package cache: \(error)")
        exit(1)
    }

    let lockPath = (cwd as NSString).appendingPathComponent("fuel.lock")
    let lockFile = FuelLockFile.read(from: lockPath)

    print("Resolving dependencies...")

    do {
        let resolved = try DependencyResolver(
            manifest: manifest,
            lockFile: lockFile,
            cache: cache
        ).resolve()

        let fetcher = PackageFetcher(cache: cache)
        for dep in resolved {
            if dep.localPath != nil {
                print("  Using \(dep.name) (local path)")
            } else if let gitURL = dep.gitURL {
                if cache.isCached(name: dep.name, version: dep.version) {
                    print("  Using \(dep.name) \(dep.version) (cached)")
                } else {
                    print("  Fetching \(dep.name) \(dep.version)...")
                    try fetcher.fetch(name: dep.name, gitURL: gitURL, version: dep.version)
                }
            }
        }

        // Write lock file
        let newLock = FuelLockFile(packages: resolved.map { dep in
            LockedPackage(
                name: dep.name,
                version: dep.version,
                gitURL: dep.gitURL,
                commitHash: dep.commitHash,
                dependencies: dep.dependencyNames
            )
        })
        try newLock.write(to: lockPath)
        print("Wrote fuel.lock (\(resolved.count) package\(resolved.count == 1 ? "" : "s"))")
    } catch {
        print("error: \(error)")
        exit(1)
    }
}

/// `rockit fuel add <name> --git <url> [--version "^1.0"]`
func fuelAddCommand(args: [String]) {
    guard !args.isEmpty else {
        print("usage: rockit fuel add <package> --git <url> [--version \"^1.0\"]")
        exit(1)
    }

    let name = args[0]
    var gitURL: String?
    var version = "*"

    var i = 1
    while i < args.count {
        switch args[i] {
        case "--git":
            i += 1
            guard i < args.count else {
                print("error: --git requires a URL argument")
                exit(1)
            }
            gitURL = args[i]
        case "--version":
            i += 1
            guard i < args.count else {
                print("error: --version requires a version constraint")
                exit(1)
            }
            version = args[i]
        default:
            print("error: unknown option '\(args[i])'")
            exit(1)
        }
        i += 1
    }

    guard gitURL != nil else {
        print("error: --git <url> is required (registry lookup not yet supported)")
        exit(1)
    }

    let fm = FileManager.default
    let cwd = fm.currentDirectoryPath
    let fuelPath = (cwd as NSString).appendingPathComponent("fuel.toml")

    guard fm.fileExists(atPath: fuelPath) else {
        print("error: no fuel.toml found in current directory")
        exit(1)
    }

    let parser = FuelManifestParser()
    guard var manifest = parser.parse(path: fuelPath) else {
        print("error: could not parse fuel.toml")
        exit(1)
    }

    // Add the dependency
    let spec: DependencySpec = .detailed(version: version, git: gitURL, path: nil, branch: nil)
    var deps = manifest.dependencies
    deps[name] = spec
    manifest = FuelManifest(package: manifest.package, dependencies: deps)

    // Write updated fuel.toml
    let serialized = parser.serialize(manifest)
    do {
        try serialized.write(toFile: fuelPath, atomically: true, encoding: .utf8)
        print("Added \(name) \(version) to fuel.toml")
    } catch {
        print("error: could not write fuel.toml: \(error)")
        exit(1)
    }

    // Install
    fuelInstallCommand()
}

/// `rockit fuel remove <name>`
func fuelRemoveCommand(args: [String]) {
    guard let name = args.first else {
        print("usage: rockit fuel remove <package>")
        exit(1)
    }

    let fm = FileManager.default
    let cwd = fm.currentDirectoryPath
    let fuelPath = (cwd as NSString).appendingPathComponent("fuel.toml")

    guard fm.fileExists(atPath: fuelPath) else {
        print("error: no fuel.toml found in current directory")
        exit(1)
    }

    let parser = FuelManifestParser()
    guard var manifest = parser.parse(path: fuelPath) else {
        print("error: could not parse fuel.toml")
        exit(1)
    }

    guard manifest.dependencies[name] != nil else {
        print("error: '\(name)' is not a dependency")
        exit(1)
    }

    var deps = manifest.dependencies
    deps.removeValue(forKey: name)
    manifest = FuelManifest(package: manifest.package, dependencies: deps)

    let serialized = parser.serialize(manifest)
    do {
        try serialized.write(toFile: fuelPath, atomically: true, encoding: .utf8)
        print("Removed \(name) from fuel.toml")
    } catch {
        print("error: could not write fuel.toml: \(error)")
        exit(1)
    }

    // Re-resolve
    if manifest.dependencies.isEmpty {
        // Remove lock file
        let lockPath = (cwd as NSString).appendingPathComponent("fuel.lock")
        try? fm.removeItem(atPath: lockPath)
        print("No remaining dependencies.")
    } else {
        fuelInstallCommand()
    }
}

// MARK: - Dependency Resolver

/// A resolved dependency with all information needed to fetch and use it
public struct ResolvedDependency {
    public let name: String
    public let version: SemanticVersion
    public let gitURL: String?
    public let localPath: String?
    public let commitHash: String
    public let dependencyNames: [String]
}

/// Resolves the full transitive dependency graph
public class DependencyResolver {
    private let manifest: FuelManifest
    private let lockFile: FuelLockFile?
    private let cache: PackageCache

    public init(manifest: FuelManifest, lockFile: FuelLockFile?, cache: PackageCache) {
        self.manifest = manifest
        self.lockFile = lockFile
        self.cache = cache
    }

    /// Resolve all dependencies, returning a flat list of resolved packages
    public func resolve() throws -> [ResolvedDependency] {
        var resolved: [String: ResolvedDependency] = [:]
        var constraints: [String: [(source: String, constraint: VersionConstraint)]] = [:]

        try resolveDependencies(
            manifest.dependencies,
            source: manifest.package.name,
            resolved: &resolved,
            constraints: &constraints
        )

        return Array(resolved.values).sorted { $0.name < $1.name }
    }

    private func resolveDependencies(
        _ deps: [String: DependencySpec],
        source: String,
        resolved: inout [String: ResolvedDependency],
        constraints: inout [String: [(source: String, constraint: VersionConstraint)]]
    ) throws {
        for (name, spec) in deps {
            // Parse version constraint
            let constraintStr = spec.versionString ?? "*"
            guard let constraint = VersionConstraint(parsing: constraintStr) else {
                throw FuelError.invalidVersionConstraint(name, constraintStr)
            }

            // Track constraints
            constraints[name, default: []].append((source: source, constraint: constraint))

            // If already resolved, verify compatibility
            if let existing = resolved[name] {
                if !constraint.satisfiedBy(existing.version) {
                    let allConstraints = constraints[name]!
                    let desc = allConstraints.map { "\($0.source) requires \($0.constraint)" }
                        .joined(separator: ", ")
                    throw FuelError.versionConflict(name, desc)
                }
                continue
            }

            // Handle path dependencies
            if let localPath = spec.localPath {
                let absPath: String
                if localPath.hasPrefix("/") {
                    absPath = localPath
                } else {
                    absPath = (FileManager.default.currentDirectoryPath as NSString)
                        .appendingPathComponent(localPath)
                }
                resolved[name] = ResolvedDependency(
                    name: name,
                    version: SemanticVersion(major: 0, minor: 0, patch: 0),
                    gitURL: nil,
                    localPath: absPath,
                    commitHash: "local",
                    dependencyNames: []
                )
                // Resolve transitive deps from the local package
                let localManifestPath = (absPath as NSString).appendingPathComponent("fuel.toml")
                if let localManifest = FuelManifestParser().parse(path: localManifestPath) {
                    try resolveDependencies(
                        localManifest.dependencies,
                        source: name,
                        resolved: &resolved,
                        constraints: &constraints
                    )
                }
                continue
            }

            // Git dependency — try lock file first
            if let locked = lockFile?.findPackage(named: name),
               constraint.satisfiedBy(locked.version) {
                resolved[name] = ResolvedDependency(
                    name: name,
                    version: locked.version,
                    gitURL: locked.gitURL ?? spec.gitURL,
                    localPath: nil,
                    commitHash: locked.commitHash,
                    dependencyNames: locked.dependencies
                )
                // Resolve transitive deps if cached
                if cache.isCached(name: name, version: locked.version) {
                    let depManifestPath = cache.manifestPath(name: name, version: locked.version)
                    if let depManifest = FuelManifestParser().parse(path: depManifestPath) {
                        try resolveDependencies(
                            depManifest.dependencies,
                            source: name,
                            resolved: &resolved,
                            constraints: &constraints
                        )
                    }
                }
                continue
            }

            // Resolve from git
            guard let gitURL = spec.gitURL else {
                throw FuelError.noSource(name)
            }

            let fetcher = PackageFetcher(cache: cache)
            let available = try fetcher.availableVersions(gitURL: gitURL)

            guard let bestVersion = constraint.bestMatch(from: available) else {
                throw FuelError.noMatchingVersion(name, constraintStr, available)
            }

            // Fetch the package to get its manifest
            if !cache.isCached(name: name, version: bestVersion) {
                try fetcher.fetch(name: name, gitURL: gitURL, version: bestVersion)
            }

            let commitHash = try fetcher.commitHash(
                packageDir: cache.packageDir(name: name, version: bestVersion)
            )

            // Read the dependency's own manifest for transitive deps
            let depManifestPath = cache.manifestPath(name: name, version: bestVersion)
            let depManifest = FuelManifestParser().parse(path: depManifestPath)
            let depNames = depManifest?.dependencies.keys.sorted() ?? []

            resolved[name] = ResolvedDependency(
                name: name,
                version: bestVersion,
                gitURL: gitURL,
                localPath: nil,
                commitHash: commitHash,
                dependencyNames: depNames
            )

            // Resolve transitive deps
            if let depManifest = depManifest, !depManifest.dependencies.isEmpty {
                try resolveDependencies(
                    depManifest.dependencies,
                    source: name,
                    resolved: &resolved,
                    constraints: &constraints
                )
            }
        }
    }
}

// MARK: - Package Fetcher

/// Handles git operations for downloading packages
public class PackageFetcher {
    private let cache: PackageCache

    public init(cache: PackageCache) {
        self.cache = cache
    }

    /// List available version tags from a git remote
    public func availableVersions(gitURL: String) throws -> [SemanticVersion] {
        let output = try runGit(["ls-remote", "--tags", gitURL])
        var versions: [SemanticVersion] = []

        for line in output.components(separatedBy: "\n") {
            // Format: <hash>\trefs/tags/<tagname>
            guard let tabIdx = line.firstIndex(of: "\t") else { continue }
            var tag = String(line[line.index(after: tabIdx)...])

            // Strip refs/tags/ prefix
            if tag.hasPrefix("refs/tags/") {
                tag = String(tag.dropFirst("refs/tags/".count))
            }
            // Skip ^{} dereferenced tags
            if tag.hasSuffix("^{}") { continue }

            if let version = SemanticVersion(parsing: tag) {
                versions.append(version)
            }
        }

        return versions.sorted()
    }

    /// Clone a specific version of a package into the cache
    public func fetch(name: String, gitURL: String, version: SemanticVersion) throws {
        let targetDir = cache.packageDir(name: name, version: version)

        // Remove if partially cached
        if FileManager.default.fileExists(atPath: targetDir) {
            try FileManager.default.removeItem(atPath: targetDir)
        }

        // Try tag formats: v1.2.3 then 1.2.3
        let tags = ["v\(version)", "\(version)"]
        var cloned = false

        for tag in tags {
            do {
                try runGit([
                    "clone", "--depth", "1", "--branch", tag,
                    gitURL, targetDir
                ])
                cloned = true
                break
            } catch {
                continue
            }
        }

        if !cloned {
            throw FuelError.fetchFailed(name, "\(version)", gitURL)
        }
    }

    /// Get the commit hash from a checked-out package directory
    public func commitHash(packageDir: String) throws -> String {
        let output = try runGit(["-C", packageDir, "rev-parse", "HEAD"])
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private

    @discardableResult
    private func runGit(_ arguments: [String]) throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            throw FuelError.gitError(arguments.first ?? "git", process.terminationStatus)
        }

        return output
    }
}

// MARK: - Errors

public enum FuelError: Error, CustomStringConvertible {
    case invalidVersionConstraint(String, String)
    case versionConflict(String, String)
    case noSource(String)
    case noMatchingVersion(String, String, [SemanticVersion])
    case fetchFailed(String, String, String)
    case gitError(String, Int32)

    public var description: String {
        switch self {
        case .invalidVersionConstraint(let pkg, let constraint):
            return "invalid version constraint '\(constraint)' for package '\(pkg)'"
        case .versionConflict(let pkg, let details):
            return "version conflict for '\(pkg)': \(details)"
        case .noSource(let pkg):
            return "no git URL or path specified for package '\(pkg)'"
        case .noMatchingVersion(let pkg, let constraint, let available):
            let avail = available.isEmpty ? "none" : available.map { "\($0)" }.joined(separator: ", ")
            return "no version of '\(pkg)' matches \(constraint) (available: \(avail))"
        case .fetchFailed(let pkg, let version, let url):
            return "failed to fetch \(pkg) \(version) from \(url)"
        case .gitError(let cmd, let code):
            return "git \(cmd) failed with exit code \(code)"
        }
    }
}
