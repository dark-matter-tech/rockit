// BuiltinFunctions.swift
// MoonKit — Moon Language Compiler
// Copyright © 2026 Dark Matter Tech. All rights reserved.

import Foundation

// MARK: - Builtin Function Type

/// Signature for built-in functions: takes arguments, returns a value.
public typealias BuiltinFunction = ([Value]) throws -> Value

// MARK: - Builtin Registry

/// Extensible registry of built-in functions available to Moon programs.
/// Built-ins are resolved by name during function dispatch.
public final class BuiltinRegistry {
    private var functions: [String: BuiltinFunction] = [:]

    public init() {
        registerDefaults()
    }

    /// Register a built-in function by name.
    public func register(name: String, function: @escaping BuiltinFunction) {
        functions[name] = function
    }

    /// Look up a built-in function. Returns nil if not registered.
    public func lookup(_ name: String) -> BuiltinFunction? {
        return functions[name]
    }

    /// Check if a function name is a built-in.
    public func isBuiltin(_ name: String) -> Bool {
        return functions[name] != nil
    }

    /// All registered built-in names.
    public var registeredNames: [String] {
        Array(functions.keys).sorted()
    }

    // MARK: - Default Built-ins

    private func registerDefaults() {
        // Output
        register(name: "println") { args in
            let text = args.map { $0.description }.joined(separator: " ")
            print(text)
            return .unit
        }

        register(name: "print") { args in
            let text = args.map { $0.description }.joined(separator: " ")
            Swift.print(text, terminator: "")
            return .unit
        }

        // String conversion
        register(name: "toString") { args in
            guard let first = args.first else { return .string("") }
            return .string(first.description)
        }

        register(name: "intToString") { args in
            guard case .int(let v) = args.first else {
                throw VMError.typeMismatch(expected: "Int", actual: args.first?.typeName ?? "nothing", operation: "intToString")
            }
            return .string("\(v)")
        }

        register(name: "floatToString") { args in
            guard case .float(let v) = args.first else {
                throw VMError.typeMismatch(expected: "Float64", actual: args.first?.typeName ?? "nothing", operation: "floatToString")
            }
            return .string("\(v)")
        }

        // String operations
        register(name: "stringLength") { args in
            guard case .string(let s) = args.first else {
                throw VMError.typeMismatch(expected: "String", actual: args.first?.typeName ?? "nothing", operation: "stringLength")
            }
            return .int(Int64(s.count))
        }

        register(name: "stringSubstring") { args in
            guard args.count >= 3,
                  case .string(let s) = args[0],
                  case .int(let start) = args[1],
                  case .int(let end) = args[2] else {
                throw VMError.typeMismatch(expected: "String, Int, Int", actual: "invalid args", operation: "stringSubstring")
            }
            let startIdx = s.index(s.startIndex, offsetBy: Int(start))
            let endIdx = s.index(s.startIndex, offsetBy: min(Int(end), s.count))
            return .string(String(s[startIdx..<endIdx]))
        }

        // Input
        register(name: "readLine") { _ in
            if let line = Swift.readLine() {
                return .string(line)
            }
            return .null
        }

        // Math
        register(name: "abs") { args in
            switch args.first {
            case .int(let v):   return .int(Swift.abs(v))
            case .float(let v): return .float(Swift.abs(v))
            default:
                throw VMError.typeMismatch(expected: "Int or Float64", actual: args.first?.typeName ?? "nothing", operation: "abs")
            }
        }

        register(name: "min") { args in
            guard args.count >= 2 else { return args.first ?? .null }
            switch (args[0], args[1]) {
            case (.int(let a), .int(let b)):     return .int(Swift.min(a, b))
            case (.float(let a), .float(let b)): return .float(Swift.min(a, b))
            default:
                throw VMError.typeMismatch(expected: "matching numeric types", actual: "\(args[0].typeName), \(args[1].typeName)", operation: "min")
            }
        }

        register(name: "max") { args in
            guard args.count >= 2 else { return args.first ?? .null }
            switch (args[0], args[1]) {
            case (.int(let a), .int(let b)):     return .int(Swift.max(a, b))
            case (.float(let a), .float(let b)): return .float(Swift.max(a, b))
            default:
                throw VMError.typeMismatch(expected: "matching numeric types", actual: "\(args[0].typeName), \(args[1].typeName)", operation: "max")
            }
        }

        // Diagnostics
        register(name: "panic") { _ in
            throw VMError.unreachable
        }

        // Type queries
        register(name: "typeOf") { args in
            guard let first = args.first else { return .string("Nothing") }
            return .string(first.typeName)
        }
    }
}
