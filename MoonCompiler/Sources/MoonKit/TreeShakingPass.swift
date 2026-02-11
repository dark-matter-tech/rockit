// TreeShakingPass.swift
// MoonKit — Moon Language Compiler
// Copyright © 2026 Dark Matter Tech. All rights reserved.

// MARK: - Tree Shaking Pass

/// Removes functions and type declarations not reachable from `main`
/// or global initializer functions.
internal final class TreeShakingPass: MIRPass {
    var name: String { "TreeShaking" }

    func run(_ module: MIRModule) -> MIRModule {
        var result = module

        // Step 1: Identify roots
        var rootFunctions = Set<String>()
        rootFunctions.insert("main")
        for global in module.globals {
            if let initFunc = global.initializerFunc {
                rootFunctions.insert(initFunc)
            }
        }

        // Step 2: Build function lookup
        let funcMap = Dictionary(uniqueKeysWithValues: module.functions.map { ($0.name, $0) })

        // Step 3: Transitively discover reachable functions and types
        var reachableFunctions = Set<String>()
        var reachableTypes = Set<String>()
        var worklist = Array(rootFunctions)

        while let funcName = worklist.popLast() {
            guard reachableFunctions.insert(funcName).inserted else { continue }
            guard let f = funcMap[funcName] else { continue }

            let refs = collectReferences(from: f)
            for refFunc in refs.functions {
                if !reachableFunctions.contains(refFunc) {
                    worklist.append(refFunc)
                }
            }
            reachableTypes.formUnion(refs.types)
        }

        // Step 4: Also mark methods of reachable types
        for typeDecl in module.types where reachableTypes.contains(typeDecl.name) {
            for method in typeDecl.methods {
                if !reachableFunctions.contains(method) {
                    worklist.append(method)
                }
            }
        }
        // Re-process newly added methods
        while let funcName = worklist.popLast() {
            guard reachableFunctions.insert(funcName).inserted else { continue }
            guard let f = funcMap[funcName] else { continue }
            let refs = collectReferences(from: f)
            for refFunc in refs.functions {
                if !reachableFunctions.contains(refFunc) {
                    worklist.append(refFunc)
                }
            }
            reachableTypes.formUnion(refs.types)
        }

        // Step 5: Filter
        result.functions = result.functions.filter { reachableFunctions.contains($0.name) }
        result.types = result.types.filter { reachableTypes.contains($0.name) }

        return result
    }

    // MARK: - Reference Collection

    private func collectReferences(from function: MIRFunction) -> (functions: Set<String>, types: Set<String>) {
        var funcs = Set<String>()
        var types = Set<String>()

        for block in function.blocks {
            for inst in block.instructions {
                switch inst {
                case .call(_, let function, _):
                    funcs.insert(function)
                case .virtualCall(_, _, let method, _):
                    // method may be "ClassName.method" — extract class name
                    funcs.insert(method)
                    if let dotIdx = method.firstIndex(of: ".") {
                        types.insert(String(method[method.startIndex..<dotIdx]))
                    }
                case .newObject(_, let typeName, _):
                    types.insert(typeName)
                case .typeCheck(_, _, let typeName),
                     .typeCast(_, _, let typeName):
                    types.insert(typeName)
                case .alloc(_, let type):
                    if case .reference(let name) = type { types.insert(name) }
                default:
                    break
                }
            }
        }

        // Collect from parameter types and return type
        for (_, paramType) in function.parameters {
            if case .reference(let name) = paramType { types.insert(name) }
        }
        if case .reference(let name) = function.returnType { types.insert(name) }

        return (funcs, types)
    }
}
