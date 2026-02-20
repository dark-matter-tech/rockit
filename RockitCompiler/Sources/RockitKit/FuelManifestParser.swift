// FuelManifestParser.swift
// RockitKit — Rockit Language Compiler
// Copyright © 2026 Dark Matter Tech. All rights reserved.

import Foundation

/// Parses fuel.toml files into FuelManifest
public class FuelManifestParser {

    public init() {}

    /// Parse a fuel.toml file at the given path
    public func parse(path: String) -> FuelManifest? {
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }
        return parse(contents: contents)
    }

    /// Parse fuel.toml contents
    public func parse(contents: String) -> FuelManifest? {
        var currentSection = ""
        var packageFields: [String: String] = [:]
        var dependencies: [String: DependencySpec] = [:]

        for line in contents.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            // Section header
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                currentSection = String(trimmed.dropFirst().dropLast())
                    .trimmingCharacters(in: .whitespaces)
                continue
            }

            // Key = value
            guard let eqIdx = trimmed.firstIndex(of: "=") else { continue }
            let key = String(trimmed[trimmed.startIndex..<eqIdx])
                .trimmingCharacters(in: .whitespaces)
            let rawValue = String(trimmed[trimmed.index(after: eqIdx)...])
                .trimmingCharacters(in: .whitespaces)

            switch currentSection {
            case "package":
                packageFields[key] = stripQuotes(rawValue)
            case "dependencies":
                if let dep = parseDependencyValue(rawValue) {
                    dependencies[key] = dep
                }
            default:
                break
            }
        }

        guard let name = packageFields["name"] else { return nil }
        let version = packageFields["version"] ?? "0.0.0"

        let packageInfo = PackageInfo(
            name: name,
            version: version,
            description: packageFields["description"]
        )

        return FuelManifest(package: packageInfo, dependencies: dependencies)
    }

    /// Serialize a FuelManifest back to fuel.toml format
    public func serialize(_ manifest: FuelManifest) -> String {
        var lines: [String] = []
        lines.append("[package]")
        lines.append("name = \"\(manifest.package.name)\"")
        lines.append("version = \"\(manifest.package.version)\"")
        if let desc = manifest.package.description {
            lines.append("description = \"\(desc)\"")
        }
        lines.append("")
        lines.append("[dependencies]")
        for (name, spec) in manifest.dependencies.sorted(by: { $0.key < $1.key }) {
            switch spec {
            case .simple(let v):
                lines.append("\(name) = \"\(v)\"")
            case .detailed(let version, let git, let path, let branch):
                var parts: [String] = []
                if let v = version { parts.append("version = \"\(v)\"") }
                if let g = git { parts.append("git = \"\(g)\"") }
                if let p = path { parts.append("path = \"\(p)\"") }
                if let b = branch { parts.append("branch = \"\(b)\"") }
                lines.append("\(name) = { \(parts.joined(separator: ", ")) }")
            }
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    private func parseDependencyValue(_ value: String) -> DependencySpec? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)

        // Inline table: { version = "^1.0", git = "https://..." }
        if trimmed.hasPrefix("{") && trimmed.hasSuffix("}") {
            return parseInlineTable(trimmed)
        }

        // Simple string: "^1.0.0"
        let stripped = stripQuotes(trimmed)
        if !stripped.isEmpty {
            return .simple(versionConstraint: stripped)
        }

        return nil
    }

    private func parseInlineTable(_ value: String) -> DependencySpec? {
        // Remove braces
        let inner = String(value.dropFirst().dropLast())
            .trimmingCharacters(in: .whitespaces)
        if inner.isEmpty { return nil }

        var fields: [String: String] = [:]
        // Split by comma, then parse each key = "value"
        for part in splitInlineTable(inner) {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            guard let eqIdx = trimmed.firstIndex(of: "=") else { continue }
            let key = String(trimmed[trimmed.startIndex..<eqIdx])
                .trimmingCharacters(in: .whitespaces)
            let val = String(trimmed[trimmed.index(after: eqIdx)...])
                .trimmingCharacters(in: .whitespaces)
            fields[key] = stripQuotes(val)
        }

        return .detailed(
            version: fields["version"],
            git: fields["git"],
            path: fields["path"],
            branch: fields["branch"]
        )
    }

    /// Split inline table content by commas, respecting quoted strings
    private func splitInlineTable(_ content: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var inQuotes = false

        for char in content {
            if char == "\"" {
                inQuotes = !inQuotes
                current.append(char)
            } else if char == "," && !inQuotes {
                parts.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty {
            parts.append(current)
        }
        return parts
    }

    private func stripQuotes(_ value: String) -> String {
        var v = value
        if v.hasPrefix("\"") && v.hasSuffix("\"") && v.count >= 2 {
            v = String(v.dropFirst().dropLast())
        }
        return v
    }
}
