// ListShiftEliminationPass.swift
// RockitKit — Rockit Language Compiler
// Copyright © 2026 Dark Matter Tech. All rights reserved.

// MARK: - List Shift Elimination Pass

/// Detects sequential list copy loops and replaces them with a single
/// `__builtin_list_shift_left` call that the codegen lowers to `llvm.memmove`.
///
/// Detects this pattern:
///     i = 0  (or any start)
///     while (i < r) {
///         listSet(list, i, toInt(listGet(list, i + 1)))
///         i = i + 1
///     }
///
/// And replaces the loop body with:
///     __builtin_list_shift_left(list, startIdx, count)
///     i = r    // update loop variable to final value
///
/// This enables LLVM to emit an optimized memmove instead of a scalar loop,
/// matching C++ performance on benchmarks like fannkuch where permutation
/// rotation uses this pattern.
internal final class ListShiftEliminationPass: MIRPass {
    var name: String { "ListShiftElimination" }

    func run(_ module: MIRModule) -> MIRModule {
        var result = module
        for i in 0..<result.functions.count {
            result.functions[i] = eliminateListShifts(result.functions[i])
        }
        return result
    }

    private func eliminateListShifts(_ function: MIRFunction) -> MIRFunction {
        var f = function

        // Build block map
        var blockMap: [String: Int] = [:]
        for (idx, block) in f.blocks.enumerated() {
            blockMap[block.label] = idx
        }

        // Find while loops: header block with branch(cond, body, exit)
        // where some block in body jumps back to header
        var loopsToTransform: [(headerIdx: Int, bodyIdx: Int, exitLabel: String,
                                listVar: String, loopVar: String, boundVar: String)] = []

        for (headerIdx, header) in f.blocks.enumerated() {
            guard case .branch(let cond, let bodyLabel, let exitLabel) = header.terminator else { continue }
            guard let bodyIdx = blockMap[bodyLabel] else { continue }

            // Header must end with: lt(cond, loopVar, boundVar)
            guard let ltInst = header.instructions.last(where: {
                if case .lt(let dest, _, _, _) = $0, dest == cond { return true }
                return false
            }) else { continue }
            guard case .lt(_, let lhsTemp, let rhsTemp, _) = ltInst else { continue }

            // Resolve lhsTemp and rhsTemp to their source variables (through load chains)
            let loopVar = resolveToSource(lhsTemp, in: header.instructions)
            let boundVar = resolveToSource(rhsTemp, in: header.instructions)
            guard loopVar != nil, boundVar != nil else { continue }

            // Body block must jump back to header
            let body = f.blocks[bodyIdx]
            guard case .jump(let backTarget) = body.terminator, backTarget == header.label else { continue }

            // Analyze the body for the sequential copy pattern
            guard let listVar = matchSequentialCopy(body: body, loopVar: loopVar!) else { continue }

            loopsToTransform.append((headerIdx: headerIdx, bodyIdx: bodyIdx, exitLabel: exitLabel,
                                     listVar: listVar, loopVar: loopVar!, boundVar: boundVar!))
        }

        // Apply transformations (reverse order to preserve indices)
        for loop in loopsToTransform.reversed() {
            let headerLabel = f.blocks[loop.headerIdx].label

            // Replace the body block with:
            //   __builtin_list_shift_left(list, loopVarStart, bound)
            //   store loopVar = bound  (set loop var to final value)
            //   jump header  (header check will fail: loopVar == bound, so exits)

            // We need to find the initial value of the loop variable.
            // For the memmove: shift_left(list, startIdx, count)
            // where startIdx is the current value of loopVar at loop entry,
            // and count is (bound - startIdx).
            // The codegen will compute these from loopVar and bound at runtime.

            // Replace body instructions with the builtin call
            f.blocks[loop.bodyIdx].instructions = [
                .call(dest: nil, function: "__builtin_list_shift_left",
                      args: [loop.listVar, loop.loopVar, loop.boundVar])
            ]
            // Store bound into loopVar so the header's lt check fails on next iteration
            // We need a temp for the load
            let boundLoadTemp = "__lse_bound_\(loop.headerIdx)"
            f.blocks[loop.bodyIdx].instructions.append(
                .load(dest: boundLoadTemp, src: loop.boundVar)
            )
            f.blocks[loop.bodyIdx].instructions.append(
                .store(dest: loop.loopVar, src: boundLoadTemp)
            )
            // Keep the jump back to header (terminator unchanged)
        }

        return f
    }

    /// Resolve a temp back to its source variable by following load chains.
    /// e.g., if temp = load(var), returns var.
    private func resolveToSource(_ temp: String, in instructions: [MIRInstruction]) -> String? {
        for inst in instructions {
            if case .load(let dest, let src) = inst, dest == temp {
                return src
            }
            // Also check if it was stored from another temp
            if case .store(let dest, let src) = inst, dest == temp {
                return resolveToSource(src, in: instructions) ?? src
            }
        }
        return nil
    }

    /// Check if a body block matches the sequential list copy pattern:
    ///   j = loopVar + 1
    ///   elem = listGet(list, j)
    ///   val = toInt(elem)
    ///   listSet(list, loopVar, val)
    ///   loopVar = j (or loopVar = loopVar + 1)
    private func matchSequentialCopy(body: MIRBasicBlock, loopVar: String) -> String? {
        let insts = body.instructions

        // Two maps:
        // 1. loadFrom: only follows load instructions (temp → variable).
        //    Used to resolve call args back to their source VARIABLE.
        // 2. valueFrom: follows both load and store chains.
        //    Used to trace computed values back through add/store/load chains.
        var loadFrom: [String: String] = [:]
        var valueFrom: [String: String] = [:]
        var constInts: [String: Int64] = [:]
        var addResults: [String: (lhs: String, rhs: String)] = [:]

        var listGetCalls: [(dest: String, list: String, idx: String)] = []
        var toIntCalls: [(dest: String, arg: String)] = []
        var listSetCalls: [(list: String, idx: String, val: String)] = []
        var loopVarUpdated = false
        var hasOtherSideEffects = false

        for inst in insts {
            switch inst {
            case .constInt(let dest, let val):
                constInts[dest] = val
            case .load(let dest, let src):
                loadFrom[dest] = src
                valueFrom[dest] = src
            case .store(let dest, let src):
                valueFrom[dest] = src
                if dest == loopVar {
                    loopVarUpdated = true
                }
            case .add(let dest, let lhs, let rhs, _):
                addResults[dest] = (lhs: lhs, rhs: rhs)
            case .call(let dest, let function, let args):
                if function == "listGet" && args.count >= 2 {
                    listGetCalls.append((dest: dest ?? "", list: args[0], idx: args[1]))
                } else if function == "toInt" && args.count == 1 {
                    toIntCalls.append((dest: dest ?? "", arg: args[0]))
                } else if function == "listSet" && args.count >= 3 {
                    listSetCalls.append((list: args[0], idx: args[1], val: args[2]))
                } else {
                    hasOtherSideEffects = true
                }
            default:
                break
            }
        }

        guard !hasOtherSideEffects else { return nil }
        guard listGetCalls.count == 1, listSetCalls.count == 1 else { return nil }
        guard loopVarUpdated else { return nil }

        let getCall = listGetCalls[0]
        let setCall = listSetCalls[0]

        // Both must use the same list (resolve through LOAD chains only —
        // call args are loaded from variables, we want the source variable)
        let getList = resolve(getCall.list, via: loadFrom)
        let setList = resolve(setCall.list, via: loadFrom)
        guard getList == setList else { return nil }

        // listGet index must be loopVar + 1.
        // Resolve through full value chain to trace val j = i + 1.
        let getIdx = resolve(getCall.idx, via: valueFrom)
        guard isVarPlusOne(getIdx, variable: loopVar, addResults: addResults,
                           valueFrom: valueFrom, constInts: constInts,
                           loadFrom: loadFrom) else { return nil }

        // listSet index must be loopVar (resolve through load chains only)
        let setIdx = resolve(setCall.idx, via: loadFrom)
        guard setIdx == loopVar else { return nil }

        // The value passed to listSet must come from listGet (possibly through toInt)
        var expectedSource = getCall.dest
        if let toInt = toIntCalls.first(where: {
            resolve($0.arg, via: loadFrom) == expectedSource || $0.arg == expectedSource
        }) {
            expectedSource = toInt.dest
        }
        let actualSource = resolve(setCall.val, via: loadFrom)
        guard actualSource == expectedSource || setCall.val == expectedSource else { return nil }

        return getList
    }

    /// Follow chains to find the root. Uses the provided map.
    private func resolve(_ temp: String, via map: [String: String]) -> String {
        var current = temp
        var visited: Set<String> = []
        while let src = map[current] {
            if visited.contains(current) { break }
            visited.insert(current)
            current = src
        }
        return current
    }

    /// Check if a temp's value is `variable + 1`.
    /// Uses valueFrom for tracing through store chains (val j = i + 1),
    /// and loadFrom for resolving add operands to their source variables.
    private func isVarPlusOne(_ temp: String, variable: String,
                               addResults: [String: (lhs: String, rhs: String)],
                               valueFrom: [String: String],
                               constInts: [String: Int64],
                               loadFrom: [String: String]) -> Bool {
        // Check if this temp is an add result
        if let add = addResults[temp] {
            // Resolve operands through load chains to get source variables
            let lhs = resolve(add.lhs, via: loadFrom)
            let rhs = resolve(add.rhs, via: loadFrom)
            // One operand is the loop variable, the other is constant 1
            if lhs == variable && (constInts[add.rhs] == 1 || constInts[rhs] == 1) { return true }
            if rhs == variable && (constInts[add.lhs] == 1 || constInts[lhs] == 1) { return true }
        }

        // Follow value-flow chain and check again (handles store/load of add result)
        if let src = valueFrom[temp] {
            return isVarPlusOne(src, variable: variable, addResults: addResults,
                                valueFrom: valueFrom, constInts: constInts,
                                loadFrom: loadFrom)
        }

        return false
    }
}
