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

        register(name: "charAt") { args in
            guard args.count >= 2,
                  case .string(let s) = args[0],
                  case .int(let index) = args[1] else {
                throw VMError.typeMismatch(expected: "String, Int", actual: "invalid args", operation: "charAt")
            }
            guard index >= 0, Int(index) < s.count else {
                throw VMError.indexOutOfBounds(index: Int(index), count: s.count)
            }
            let charIdx = s.index(s.startIndex, offsetBy: Int(index))
            return .string(String(s[charIdx]))
        }

        register(name: "stringIndexOf") { args in
            guard args.count >= 2,
                  case .string(let s) = args[0],
                  case .string(let search) = args[1] else {
                throw VMError.typeMismatch(expected: "String, String", actual: "invalid args", operation: "stringIndexOf")
            }
            if let range = s.range(of: search) {
                return .int(Int64(s.distance(from: s.startIndex, to: range.lowerBound)))
            }
            return .int(-1)
        }

        register(name: "startsWith") { args in
            guard args.count >= 2,
                  case .string(let s) = args[0],
                  case .string(let prefix) = args[1] else {
                throw VMError.typeMismatch(expected: "String, String", actual: "invalid args", operation: "startsWith")
            }
            return .bool(s.hasPrefix(prefix))
        }

        register(name: "endsWith") { args in
            guard args.count >= 2,
                  case .string(let s) = args[0],
                  case .string(let suffix) = args[1] else {
                throw VMError.typeMismatch(expected: "String, String", actual: "invalid args", operation: "endsWith")
            }
            return .bool(s.hasSuffix(suffix))
        }

        register(name: "stringContains") { args in
            guard args.count >= 2,
                  case .string(let s) = args[0],
                  case .string(let search) = args[1] else {
                throw VMError.typeMismatch(expected: "String, String", actual: "invalid args", operation: "stringContains")
            }
            return .bool(s.contains(search))
        }

        register(name: "stringTrim") { args in
            guard case .string(let s) = args.first else {
                throw VMError.typeMismatch(expected: "String", actual: args.first?.typeName ?? "nothing", operation: "stringTrim")
            }
            return .string(s.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        register(name: "stringReplace") { args in
            guard args.count >= 3,
                  case .string(let s) = args[0],
                  case .string(let target) = args[1],
                  case .string(let replacement) = args[2] else {
                throw VMError.typeMismatch(expected: "String, String, String", actual: "invalid args", operation: "stringReplace")
            }
            return .string(s.replacingOccurrences(of: target, with: replacement))
        }

        register(name: "stringToLower") { args in
            guard case .string(let s) = args.first else {
                throw VMError.typeMismatch(expected: "String", actual: args.first?.typeName ?? "nothing", operation: "stringToLower")
            }
            return .string(s.lowercased())
        }

        register(name: "stringToUpper") { args in
            guard case .string(let s) = args.first else {
                throw VMError.typeMismatch(expected: "String", actual: args.first?.typeName ?? "nothing", operation: "stringToUpper")
            }
            return .string(s.uppercased())
        }

        // Character classification
        register(name: "isDigit") { args in
            guard case .string(let s) = args.first, let ch = s.first else {
                throw VMError.typeMismatch(expected: "String (single char)", actual: args.first?.typeName ?? "nothing", operation: "isDigit")
            }
            return .bool(ch.isNumber)
        }

        register(name: "isLetter") { args in
            guard case .string(let s) = args.first, let ch = s.first else {
                throw VMError.typeMismatch(expected: "String (single char)", actual: args.first?.typeName ?? "nothing", operation: "isLetter")
            }
            return .bool(ch.isLetter)
        }

        register(name: "isWhitespace") { args in
            guard case .string(let s) = args.first, let ch = s.first else {
                throw VMError.typeMismatch(expected: "String (single char)", actual: args.first?.typeName ?? "nothing", operation: "isWhitespace")
            }
            return .bool(ch.isWhitespace)
        }

        register(name: "isLetterOrDigit") { args in
            guard case .string(let s) = args.first, let ch = s.first else {
                throw VMError.typeMismatch(expected: "String (single char)", actual: args.first?.typeName ?? "nothing", operation: "isLetterOrDigit")
            }
            return .bool(ch.isLetter || ch.isNumber)
        }

        register(name: "charToInt") { args in
            guard case .string(let s) = args.first, let ch = s.first else {
                throw VMError.typeMismatch(expected: "String (single char)", actual: args.first?.typeName ?? "nothing", operation: "charToInt")
            }
            return .int(Int64(ch.asciiValue ?? 0))
        }

        register(name: "intToChar") { args in
            guard case .int(let code) = args.first else {
                throw VMError.typeMismatch(expected: "Int", actual: args.first?.typeName ?? "nothing", operation: "intToChar")
            }
            guard code >= 0, code <= 127, let scalar = UnicodeScalar(Int(code)) else {
                return .string("")
            }
            return .string(String(Character(scalar)))
        }

        // Input
        register(name: "readLine") { _ in
            if let line = Swift.readLine() {
                return .string(line)
            }
            return .null
        }

        // File I/O
        register(name: "fileRead") { args in
            guard case .string(let path) = args.first else {
                throw VMError.typeMismatch(expected: "String", actual: args.first?.typeName ?? "nothing", operation: "fileRead")
            }
            do {
                let contents = try String(contentsOfFile: path, encoding: .utf8)
                return .string(contents)
            } catch {
                return .null
            }
        }

        register(name: "fileWrite") { args in
            guard args.count >= 2,
                  case .string(let path) = args[0],
                  case .string(let content) = args[1] else {
                throw VMError.typeMismatch(expected: "String, String", actual: "invalid args", operation: "fileWrite")
            }
            do {
                try content.write(toFile: path, atomically: true, encoding: .utf8)
                return .bool(true)
            } catch {
                return .bool(false)
            }
        }

        register(name: "fileExists") { args in
            guard case .string(let path) = args.first else {
                throw VMError.typeMismatch(expected: "String", actual: args.first?.typeName ?? "nothing", operation: "fileExists")
            }
            return .bool(FileManager.default.fileExists(atPath: path))
        }

        register(name: "fileDelete") { args in
            guard case .string(let path) = args.first else {
                throw VMError.typeMismatch(expected: "String", actual: args.first?.typeName ?? "nothing", operation: "fileDelete")
            }
            do {
                try FileManager.default.removeItem(atPath: path)
                return .bool(true)
            } catch {
                return .bool(false)
            }
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

    // MARK: - Collection Builtins

    /// Register collection builtins that need heap and ARC access.
    /// Called by VM after heap and ARC are initialized.
    public func registerCollectionBuiltins(heap: Heap, arc: ReferenceCounter) {
        registerListBuiltins(heap: heap, arc: arc)
        registerHashMapBuiltins(heap: heap, arc: arc)
        registerHeapAwareStringBuiltins(heap: heap)
    }

    // MARK: List Builtins

    private func registerListBuiltins(heap: Heap, arc: ReferenceCounter) {
        func extractList(_ args: [Value], operation: String) throws -> MoonObject {
            guard let first = args.first, case .objectRef(let id) = first else {
                throw VMError.typeMismatch(
                    expected: "List",
                    actual: args.first?.typeName ?? "nothing",
                    operation: operation
                )
            }
            let obj = try heap.get(id)
            guard obj.typeName == "List" || obj.typeName == "MutableList" else {
                throw VMError.typeMismatch(
                    expected: "List", actual: obj.typeName, operation: operation
                )
            }
            return obj
        }

        register(name: "listCreate") { _ in
            let id = heap.allocate(typeName: "List")
            let obj = try heap.get(id)
            obj.listStorage = []
            return .objectRef(id)
        }

        register(name: "listAppend") { args in
            let obj = try extractList(args, operation: "listAppend")
            guard args.count >= 2 else {
                throw VMError.typeMismatch(expected: "2 arguments", actual: "\(args.count)", operation: "listAppend")
            }
            let element = args[1]
            obj.listStorage?.append(element)
            arc.retain(element)
            return .unit
        }

        register(name: "listGet") { args in
            let obj = try extractList(args, operation: "listGet")
            guard args.count >= 2, case .int(let index) = args[1] else {
                throw VMError.typeMismatch(expected: "Int", actual: args.count >= 2 ? args[1].typeName : "nothing", operation: "listGet")
            }
            guard let storage = obj.listStorage, index >= 0, Int(index) < storage.count else {
                throw VMError.indexOutOfBounds(index: Int(index), count: obj.listStorage?.count ?? 0)
            }
            return storage[Int(index)]
        }

        register(name: "listSet") { args in
            let obj = try extractList(args, operation: "listSet")
            guard args.count >= 3, case .int(let index) = args[1] else {
                throw VMError.typeMismatch(expected: "Int", actual: args.count >= 2 ? args[1].typeName : "nothing", operation: "listSet")
            }
            let newValue = args[2]
            guard obj.listStorage != nil, index >= 0, Int(index) < obj.listStorage!.count else {
                throw VMError.indexOutOfBounds(index: Int(index), count: obj.listStorage?.count ?? 0)
            }
            let oldValue = obj.listStorage![Int(index)]
            obj.listStorage![Int(index)] = newValue
            arc.retain(newValue)
            arc.release(oldValue)
            return .unit
        }

        register(name: "listSize") { args in
            let obj = try extractList(args, operation: "listSize")
            return .int(Int64(obj.listStorage?.count ?? 0))
        }

        register(name: "listRemoveAt") { args in
            let obj = try extractList(args, operation: "listRemoveAt")
            guard args.count >= 2, case .int(let index) = args[1] else {
                throw VMError.typeMismatch(expected: "Int", actual: args.count >= 2 ? args[1].typeName : "nothing", operation: "listRemoveAt")
            }
            guard obj.listStorage != nil, index >= 0, Int(index) < obj.listStorage!.count else {
                throw VMError.indexOutOfBounds(index: Int(index), count: obj.listStorage?.count ?? 0)
            }
            let removed = obj.listStorage!.remove(at: Int(index))
            // Ownership transfer: list's retain becomes caller's retain
            return removed
        }

        register(name: "listContains") { args in
            let obj = try extractList(args, operation: "listContains")
            guard args.count >= 2 else {
                throw VMError.typeMismatch(expected: "2 arguments", actual: "\(args.count)", operation: "listContains")
            }
            return .bool(obj.listStorage?.contains(args[1]) ?? false)
        }

        register(name: "listIndexOf") { args in
            let obj = try extractList(args, operation: "listIndexOf")
            guard args.count >= 2 else {
                throw VMError.typeMismatch(expected: "2 arguments", actual: "\(args.count)", operation: "listIndexOf")
            }
            if let index = obj.listStorage?.firstIndex(of: args[1]) {
                return .int(Int64(index))
            }
            return .int(-1)
        }

        register(name: "listIsEmpty") { args in
            let obj = try extractList(args, operation: "listIsEmpty")
            return .bool(obj.listStorage?.isEmpty ?? true)
        }

        register(name: "listClear") { args in
            let obj = try extractList(args, operation: "listClear")
            if let elements = obj.listStorage {
                for element in elements {
                    arc.release(element)
                }
            }
            obj.listStorage = []
            return .unit
        }
    }

    // MARK: HashMap Builtins

    private func registerHashMapBuiltins(heap: Heap, arc: ReferenceCounter) {
        func extractMap(_ args: [Value], operation: String) throws -> MoonObject {
            guard let first = args.first, case .objectRef(let id) = first else {
                throw VMError.typeMismatch(
                    expected: "HashMap",
                    actual: args.first?.typeName ?? "nothing",
                    operation: operation
                )
            }
            let obj = try heap.get(id)
            guard obj.typeName == "HashMap" || obj.typeName == "Map" || obj.typeName == "MutableMap" else {
                throw VMError.typeMismatch(
                    expected: "HashMap", actual: obj.typeName, operation: operation
                )
            }
            return obj
        }

        register(name: "mapCreate") { _ in
            let id = heap.allocate(typeName: "HashMap")
            let obj = try heap.get(id)
            obj.mapStorage = [:]
            return .objectRef(id)
        }

        register(name: "mapPut") { args in
            let obj = try extractMap(args, operation: "mapPut")
            guard args.count >= 3 else {
                throw VMError.typeMismatch(expected: "3 arguments", actual: "\(args.count)", operation: "mapPut")
            }
            let key = args[1]
            let newValue = args[2]
            if let oldValue = obj.mapStorage?[key] {
                // Key exists: release old value, retain new value
                arc.release(oldValue)
            } else {
                // New key: retain the key
                arc.retain(key)
            }
            obj.mapStorage?[key] = newValue
            arc.retain(newValue)
            return .unit
        }

        register(name: "mapGet") { args in
            let obj = try extractMap(args, operation: "mapGet")
            guard args.count >= 2 else {
                throw VMError.typeMismatch(expected: "2 arguments", actual: "\(args.count)", operation: "mapGet")
            }
            return obj.mapStorage?[args[1]] ?? .null
        }

        register(name: "mapRemove") { args in
            let obj = try extractMap(args, operation: "mapRemove")
            guard args.count >= 2 else {
                throw VMError.typeMismatch(expected: "2 arguments", actual: "\(args.count)", operation: "mapRemove")
            }
            let key = args[1]
            guard let removedValue = obj.mapStorage?.removeValue(forKey: key) else {
                return .null
            }
            arc.release(key)
            // Ownership transfer for value: map's retain becomes caller's retain
            return removedValue
        }

        register(name: "mapContainsKey") { args in
            let obj = try extractMap(args, operation: "mapContainsKey")
            guard args.count >= 2 else {
                throw VMError.typeMismatch(expected: "2 arguments", actual: "\(args.count)", operation: "mapContainsKey")
            }
            return .bool(obj.mapStorage?[args[1]] != nil)
        }

        register(name: "mapKeys") { args in
            let obj = try extractMap(args, operation: "mapKeys")
            let keys = obj.mapStorage.map { Array($0.keys) } ?? []
            let listId = heap.allocate(typeName: "List")
            let listObj = try heap.get(listId)
            listObj.listStorage = keys
            for key in keys {
                arc.retain(key)
            }
            return .objectRef(listId)
        }

        register(name: "mapValues") { args in
            let obj = try extractMap(args, operation: "mapValues")
            let values = obj.mapStorage.map { Array($0.values) } ?? []
            let listId = heap.allocate(typeName: "List")
            let listObj = try heap.get(listId)
            listObj.listStorage = values
            for value in values {
                arc.retain(value)
            }
            return .objectRef(listId)
        }

        register(name: "mapSize") { args in
            let obj = try extractMap(args, operation: "mapSize")
            return .int(Int64(obj.mapStorage?.count ?? 0))
        }

        register(name: "mapIsEmpty") { args in
            let obj = try extractMap(args, operation: "mapIsEmpty")
            return .bool(obj.mapStorage?.isEmpty ?? true)
        }

        register(name: "mapClear") { args in
            let obj = try extractMap(args, operation: "mapClear")
            if let entries = obj.mapStorage {
                for (key, value) in entries {
                    arc.release(key)
                    arc.release(value)
                }
            }
            obj.mapStorage = [:]
            return .unit
        }
    }

    // MARK: Heap-Aware String Builtins

    private func registerHeapAwareStringBuiltins(heap: Heap) {
        register(name: "stringSplit") { args in
            guard args.count >= 2,
                  case .string(let s) = args[0],
                  case .string(let delimiter) = args[1] else {
                throw VMError.typeMismatch(expected: "String, String", actual: "invalid args", operation: "stringSplit")
            }
            let parts = delimiter.isEmpty ? s.map { String($0) } : s.components(separatedBy: delimiter)
            let listId = heap.allocate(typeName: "List")
            let listObj = try heap.get(listId)
            listObj.listStorage = parts.map { .string($0) }
            return .objectRef(listId)
        }

        register(name: "stringConcat") { args in
            guard args.count >= 2,
                  case .string(let a) = args[0],
                  case .string(let b) = args[1] else {
                throw VMError.typeMismatch(expected: "String, String", actual: "invalid args", operation: "stringConcat")
            }
            return .string(a + b)
        }

        register(name: "stringFromCharCodes") { args in
            guard args.count >= 1, case .objectRef(let id) = args[0] else {
                throw VMError.typeMismatch(expected: "List of Int", actual: args.first?.typeName ?? "nothing", operation: "stringFromCharCodes")
            }
            let obj = try heap.get(id)
            guard let elements = obj.listStorage else {
                throw VMError.typeMismatch(expected: "List", actual: obj.typeName, operation: "stringFromCharCodes")
            }
            var result = ""
            for element in elements {
                guard case .int(let code) = element, let scalar = UnicodeScalar(Int(code)) else { continue }
                result.append(Character(scalar))
            }
            return .string(result)
        }
    }
}
