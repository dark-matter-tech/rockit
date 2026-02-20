// FuelTests.swift
// RockitKit Tests
// Copyright © 2026 Dark Matter Tech. All rights reserved.

import XCTest
@testable import RockitKit

final class FuelTests: XCTestCase {

    // MARK: - SemanticVersion

    func testVersionParsing() {
        let v = SemanticVersion(parsing: "1.2.3")
        XCTAssertNotNil(v)
        XCTAssertEqual(v?.major, 1)
        XCTAssertEqual(v?.minor, 2)
        XCTAssertEqual(v?.patch, 3)
    }

    func testVersionParsingWithV() {
        let v = SemanticVersion(parsing: "v2.0.1")
        XCTAssertNotNil(v)
        XCTAssertEqual(v?.major, 2)
        XCTAssertEqual(v?.minor, 0)
        XCTAssertEqual(v?.patch, 1)
    }

    func testVersionParsingInvalid() {
        XCTAssertNil(SemanticVersion(parsing: "1.2"))
        XCTAssertNil(SemanticVersion(parsing: "abc"))
        XCTAssertNil(SemanticVersion(parsing: ""))
        XCTAssertNil(SemanticVersion(parsing: "1.2.3.4"))
    }

    func testVersionComparison() {
        let v1 = SemanticVersion(major: 1, minor: 0, patch: 0)
        let v2 = SemanticVersion(major: 1, minor: 2, patch: 0)
        let v3 = SemanticVersion(major: 2, minor: 0, patch: 0)
        let v4 = SemanticVersion(major: 1, minor: 2, patch: 3)

        XCTAssertTrue(v1 < v2)
        XCTAssertTrue(v2 < v3)
        XCTAssertTrue(v2 < v4)
        XCTAssertTrue(v1 < v3)
        XCTAssertEqual(v1, SemanticVersion(major: 1, minor: 0, patch: 0))
    }

    func testVersionDescription() {
        let v = SemanticVersion(major: 3, minor: 14, patch: 159)
        XCTAssertEqual(v.description, "3.14.159")
    }

    // MARK: - VersionConstraint

    func testCaretConstraint() {
        let c = VersionConstraint(parsing: "^1.2.3")!
        XCTAssertTrue(c.satisfiedBy(SemanticVersion(major: 1, minor: 2, patch: 3)))
        XCTAssertTrue(c.satisfiedBy(SemanticVersion(major: 1, minor: 3, patch: 0)))
        XCTAssertTrue(c.satisfiedBy(SemanticVersion(major: 1, minor: 99, patch: 99)))
        XCTAssertFalse(c.satisfiedBy(SemanticVersion(major: 2, minor: 0, patch: 0)))
        XCTAssertFalse(c.satisfiedBy(SemanticVersion(major: 1, minor: 2, patch: 2)))
        XCTAssertFalse(c.satisfiedBy(SemanticVersion(major: 0, minor: 9, patch: 9)))
    }

    func testCaretConstraintZeroMajor() {
        // ^0.2.3 means >=0.2.3, <0.3.0
        let c = VersionConstraint(parsing: "^0.2.3")!
        XCTAssertTrue(c.satisfiedBy(SemanticVersion(major: 0, minor: 2, patch: 3)))
        XCTAssertTrue(c.satisfiedBy(SemanticVersion(major: 0, minor: 2, patch: 9)))
        XCTAssertFalse(c.satisfiedBy(SemanticVersion(major: 0, minor: 3, patch: 0)))
        XCTAssertFalse(c.satisfiedBy(SemanticVersion(major: 1, minor: 0, patch: 0)))
    }

    func testTildeConstraint() {
        let c = VersionConstraint(parsing: "~1.2.3")!
        XCTAssertTrue(c.satisfiedBy(SemanticVersion(major: 1, minor: 2, patch: 3)))
        XCTAssertTrue(c.satisfiedBy(SemanticVersion(major: 1, minor: 2, patch: 9)))
        XCTAssertFalse(c.satisfiedBy(SemanticVersion(major: 1, minor: 3, patch: 0)))
        XCTAssertFalse(c.satisfiedBy(SemanticVersion(major: 2, minor: 0, patch: 0)))
    }

    func testExactConstraint() {
        let c = VersionConstraint(parsing: "1.2.3")!
        XCTAssertTrue(c.satisfiedBy(SemanticVersion(major: 1, minor: 2, patch: 3)))
        XCTAssertFalse(c.satisfiedBy(SemanticVersion(major: 1, minor: 2, patch: 4)))
    }

    func testGreaterOrEqualConstraint() {
        let c = VersionConstraint(parsing: ">=1.0.0")!
        XCTAssertTrue(c.satisfiedBy(SemanticVersion(major: 1, minor: 0, patch: 0)))
        XCTAssertTrue(c.satisfiedBy(SemanticVersion(major: 2, minor: 0, patch: 0)))
        XCTAssertTrue(c.satisfiedBy(SemanticVersion(major: 99, minor: 0, patch: 0)))
        XCTAssertFalse(c.satisfiedBy(SemanticVersion(major: 0, minor: 9, patch: 9)))
    }

    func testAnyConstraint() {
        let c = VersionConstraint(parsing: "*")!
        XCTAssertTrue(c.satisfiedBy(SemanticVersion(major: 0, minor: 0, patch: 0)))
        XCTAssertTrue(c.satisfiedBy(SemanticVersion(major: 99, minor: 99, patch: 99)))
    }

    func testBestMatch() {
        let c = VersionConstraint(parsing: "^1.0.0")!
        let versions = [
            SemanticVersion(major: 0, minor: 9, patch: 0),
            SemanticVersion(major: 1, minor: 0, patch: 0),
            SemanticVersion(major: 1, minor: 2, patch: 3),
            SemanticVersion(major: 1, minor: 5, patch: 0),
            SemanticVersion(major: 2, minor: 0, patch: 0),
        ]
        let best = c.bestMatch(from: versions)
        XCTAssertEqual(best, SemanticVersion(major: 1, minor: 5, patch: 0))
    }

    func testConstraintDescription() {
        XCTAssertEqual(VersionConstraint(parsing: "^1.2.3")?.description, "^1.2.3")
        XCTAssertEqual(VersionConstraint(parsing: "~1.2.3")?.description, "~1.2.3")
        XCTAssertEqual(VersionConstraint(parsing: ">=1.0.0")?.description, ">=1.0.0")
        XCTAssertEqual(VersionConstraint(parsing: "1.2.3")?.description, "1.2.3")
        XCTAssertEqual(VersionConstraint(parsing: "*")?.description, "*")
    }

    // MARK: - FuelManifestParser

    func testParseSimpleManifest() {
        let toml = """
        [package]
        name = "myapp"
        version = "0.1.0"
        description = "My application"

        [dependencies]
        json = "^1.0.0"
        math = "~2.1.0"
        """

        let parser = FuelManifestParser()
        let manifest = parser.parse(contents: toml)
        XCTAssertNotNil(manifest)
        XCTAssertEqual(manifest?.package.name, "myapp")
        XCTAssertEqual(manifest?.package.version, "0.1.0")
        XCTAssertEqual(manifest?.package.description, "My application")
        XCTAssertEqual(manifest?.dependencies.count, 2)

        if case .simple(let v) = manifest?.dependencies["json"] {
            XCTAssertEqual(v, "^1.0.0")
        } else {
            XCTFail("Expected simple dependency for json")
        }
    }

    func testParseInlineTableDependency() {
        let toml = """
        [package]
        name = "myapp"
        version = "0.1.0"

        [dependencies]
        http = { version = "~2.1", git = "https://example.com/http.git" }
        utils = { path = "../my-utils" }
        """

        let parser = FuelManifestParser()
        let manifest = parser.parse(contents: toml)
        XCTAssertNotNil(manifest)
        XCTAssertEqual(manifest?.dependencies.count, 2)

        XCTAssertEqual(manifest?.dependencies["http"]?.versionString, "~2.1")
        XCTAssertEqual(manifest?.dependencies["http"]?.gitURL, "https://example.com/http.git")
        XCTAssertEqual(manifest?.dependencies["utils"]?.localPath, "../my-utils")
    }

    func testParseNoDependencies() {
        let toml = """
        [package]
        name = "simple"
        version = "1.0.0"

        [dependencies]
        """

        let parser = FuelManifestParser()
        let manifest = parser.parse(contents: toml)
        XCTAssertNotNil(manifest)
        XCTAssertEqual(manifest?.dependencies.count, 0)
    }

    func testSerializeRoundtrip() {
        let original = FuelManifest(
            package: PackageInfo(name: "test", version: "1.0.0", description: "A test"),
            dependencies: [
                "json": .simple(versionConstraint: "^1.0.0"),
                "http": .detailed(version: "~2.0", git: "https://example.com/http.git", path: nil, branch: nil)
            ]
        )

        let parser = FuelManifestParser()
        let serialized = parser.serialize(original)
        let parsed = parser.parse(contents: serialized)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.package.name, "test")
        XCTAssertEqual(parsed?.package.version, "1.0.0")
        XCTAssertEqual(parsed?.dependencies.count, 2)
        XCTAssertEqual(parsed?.dependencies["json"]?.versionString, "^1.0.0")
        XCTAssertEqual(parsed?.dependencies["http"]?.versionString, "~2.0")
        XCTAssertEqual(parsed?.dependencies["http"]?.gitURL, "https://example.com/http.git")
    }

    // MARK: - FuelLockFile

    func testLockFileParseAndSerialize() {
        let lockContent = """
        # fuel.lock — auto-generated by Fuel, do not edit

        [[package]]
        name = "json"
        version = "1.2.4"
        git = "https://example.com/json.git"
        commit = "abc123"
        dependencies = []

        [[package]]
        name = "http"
        version = "2.1.3"
        git = "https://example.com/http.git"
        commit = "def456"
        dependencies = ["json"]
        """

        let lockFile = FuelLockFile.parse(contents: lockContent)
        XCTAssertNotNil(lockFile)
        XCTAssertEqual(lockFile?.packages.count, 2)

        let http = lockFile?.findPackage(named: "http")
        XCTAssertNotNil(http)
        XCTAssertEqual(http?.version, SemanticVersion(major: 2, minor: 1, patch: 3))
        XCTAssertEqual(http?.commitHash, "def456")
        XCTAssertEqual(http?.dependencies, ["json"])

        // Roundtrip — serialize sorts by name, so compare package sets
        let serialized = lockFile!.serialize()
        let reparsed = FuelLockFile.parse(contents: serialized)
        XCTAssertNotNil(reparsed)
        XCTAssertEqual(reparsed?.packages.count, 2)
        XCTAssertNotNil(reparsed?.findPackage(named: "json"))
        XCTAssertNotNil(reparsed?.findPackage(named: "http"))
        XCTAssertEqual(reparsed?.findPackage(named: "json")?.commitHash, "abc123")
        XCTAssertEqual(reparsed?.findPackage(named: "http")?.dependencies, ["json"])
    }

    func testLockFileFindPackage() {
        let lockFile = FuelLockFile(packages: [
            LockedPackage(name: "foo", version: SemanticVersion(major: 1, minor: 0, patch: 0), gitURL: nil, commitHash: "abc", dependencies: []),
            LockedPackage(name: "bar", version: SemanticVersion(major: 2, minor: 0, patch: 0), gitURL: nil, commitHash: "def", dependencies: []),
        ])

        XCTAssertNotNil(lockFile.findPackage(named: "foo"))
        XCTAssertNotNil(lockFile.findPackage(named: "bar"))
        XCTAssertNil(lockFile.findPackage(named: "baz"))
    }
}
