// FlagLoopEliminationPass.swift
// RockitKit — Rockit Language Compiler
// Copyright © 2026 Dark Matter Tech. All rights reserved.

// MARK: - Flag Loop Elimination Pass

/// Converts flag-controlled while loops to direct-branch loops.
///
/// Detects this pattern:
///     var flag = 0
///     while (flag == 0) {
///         ...
///         flag = 1   // exit point
///         ...
///     }
///
/// And transforms it to:
///     while (true) {
///         ...
///         jump while.exit   // direct exit
///         ...
///     }
///
/// This enables LLVM to better analyze loop trip counts and perform full
/// unrolling, which is critical for matching C++ performance on benchmarks
/// like fannkuch where the advance loop uses a flag-based exit pattern.
internal final class FlagLoopEliminationPass: MIRPass {
    var name: String { "FlagLoopElimination" }

    func run(_ module: MIRModule) -> MIRModule {
        var result = module
        for i in 0..<result.functions.count {
            result.functions[i] = eliminateFlagLoops(result.functions[i])
        }
        return result
    }

    private func eliminateFlagLoops(_ function: MIRFunction) -> MIRFunction {
        var f = function

        // Build a block map for efficient lookup
        var blockMap: [String: Int] = [:]
        for (idx, block) in f.blocks.enumerated() {
            blockMap[block.label] = idx
        }

        // Find flag-controlled while loops.
        // Pattern: a block ending with branch(cond, bodyLabel, exitLabel)
        // where cond = eq(flagLoad, zero) and flagLoad = load(flagVar)
        // and flagVar is only used as a boolean loop exit flag.
        var loopsToTransform: [(headerIdx: Int, flagVar: String, exitLabel: String, bodyLabel: String)] = []

        for (blockIdx, block) in f.blocks.enumerated() {
            guard case .branch(let cond, let thenLabel, let elseLabel) = block.terminator else { continue }

            // The header should have: load flagTemp flagVar; constInt zero 0; eq cond flagTemp zero
            // Find the eq instruction that produces `cond`
            guard let eqInst = block.instructions.last(where: {
                if case .eq(let dest, _, _, _) = $0, dest == cond { return true }
                return false
            }) else { continue }

            guard case .eq(_, let lhs, let rhs, _) = eqInst else { continue }

            // One operand should be a constant 0, the other should be a load of the flag
            var flagLoadTemp: String?
            var zeroTemp: String?
            for inst in block.instructions {
                if case .constInt(let dest, 0) = inst {
                    if dest == lhs || dest == rhs {
                        zeroTemp = dest
                        flagLoadTemp = (dest == lhs) ? rhs : lhs
                    }
                }
            }
            guard let flagLoad = flagLoadTemp, zeroTemp != nil else { continue }

            // Find the load instruction for the flag
            guard let loadInst = block.instructions.last(where: {
                if case .load(let dest, _) = $0, dest == flagLoad { return true }
                return false
            }) else { continue }

            guard case .load(_, let flagVar) = loadInst else { continue }

            // thenLabel should be the body (flag == 0 → continue), elseLabel should be exit
            let bodyLabel = thenLabel
            let exitLabel = elseLabel

            // Verify this looks like a while loop: some block inside the loop should
            // jump back to this header
            let headerLabel = block.label
            var hasBackEdge = false
            for otherBlock in f.blocks {
                if case .jump(let target) = otherBlock.terminator, target == headerLabel {
                    hasBackEdge = true
                    break
                }
            }
            guard hasBackEdge else { continue }

            // Verify the flag variable is only used for loop control:
            // - Stored with 0 (initialization) and 1 (exit signal)
            // - Loaded only in this header block
            // - Not passed to any function call
            var flagStoreValues: Set<Int64> = []
            var flagLoadCount = 0
            var flagUsedInCall = false
            var constIntMap: [String: Int64] = [:]

            for blk in f.blocks {
                for inst in blk.instructions {
                    if case .constInt(let dest, let value) = inst {
                        constIntMap[dest] = value
                    }
                    if case .store(let dest, let src) = inst, dest == flagVar {
                        if let val = constIntMap[src] {
                            flagStoreValues.insert(val)
                        } else {
                            // Unknown value stored — can't optimize
                            flagUsedInCall = true
                        }
                    }
                    if case .load(_, let src) = inst, src == flagVar {
                        flagLoadCount += 1
                    }
                    if case .call(_, _, let args) = inst, args.contains(flagVar) {
                        flagUsedInCall = true
                    }
                    if case .callIndirect(_, _, let args) = inst, args.contains(flagVar) {
                        flagUsedInCall = true
                    }
                }
            }

            // Flag must only be stored with 0 and 1, loaded only once (in header), not used in calls
            guard !flagUsedInCall else { continue }
            guard flagStoreValues.isSubset(of: [0, 1]) else { continue }
            guard flagStoreValues.contains(1) else { continue } // Must have exit stores
            guard flagLoadCount == 1 else { continue } // Only loaded in header

            loopsToTransform.append((headerIdx: blockIdx, flagVar: flagVar,
                                     exitLabel: exitLabel, bodyLabel: bodyLabel))
        }

        // Apply transformations (process in reverse to maintain indices)
        for loop in loopsToTransform.reversed() {
            let headerLabel = f.blocks[loop.headerIdx].label

            // Step 1: Find all blocks inside the loop that store 1 to the flag
            // and redirect them to jump to the exit
            var constOnes: Set<String> = [] // temps known to hold value 1
            for blk in f.blocks {
                for inst in blk.instructions {
                    if case .constInt(let dest, 1) = inst {
                        constOnes.insert(dest)
                    }
                }
            }

            // First pass: identify all blocks that store 1 to the flag and
            // check if ALL of them can be redirected to the exit.
            var flagStoreBlocks: [(blockIdx: Int, newInstructions: [MIRInstruction])] = []
            var allRedirectable = true

            for blockIdx in 0..<f.blocks.count {
                var newInstructions: [MIRInstruction] = []
                var foundFlagStore = false

                for inst in f.blocks[blockIdx].instructions {
                    if case .store(let dest, let src) = inst,
                       dest == loop.flagVar, constOnes.contains(src) {
                        foundFlagStore = true
                        continue
                    }
                    newInstructions.append(inst)
                }

                if foundFlagStore {
                    // Check if this block can be redirected to the exit
                    var canRedirect = false
                    if case .jump(let target) = f.blocks[blockIdx].terminator {
                        canRedirect = eventuallyReachesHeader(from: target, header: headerLabel,
                                                              blocks: f.blocks, blockMap: blockMap)
                    }
                    if !canRedirect {
                        allRedirectable = false
                        break
                    }
                    flagStoreBlocks.append((blockIdx: blockIdx, newInstructions: newInstructions))
                }
            }

            // Only apply the transformation if ALL flag stores can be redirected.
            // Otherwise, making the header unconditional would create an infinite loop.
            guard allRedirectable, !flagStoreBlocks.isEmpty else { continue }

            // Apply: remove flag stores and redirect terminators
            for entry in flagStoreBlocks {
                f.blocks[entry.blockIdx].instructions = entry.newInstructions
                f.blocks[entry.blockIdx].terminator = .jump(loop.exitLabel)
            }

            // Step 2: Change the while header to unconditional jump to body.
            // Remove the flag load, const 0, and eq instructions.
            f.blocks[loop.headerIdx].instructions = f.blocks[loop.headerIdx].instructions.filter { inst in
                // Remove constInt that produces the zero for comparison
                if case .constInt(_, 0) = inst { return false }
                // Remove load of the flag variable
                if case .load(_, let src) = inst, src == loop.flagVar { return false }
                // Remove the eq comparison
                if case .eq(_, _, _, _) = inst { return false }
                return true
            }
            f.blocks[loop.headerIdx].terminator = .jump(loop.bodyLabel)
        }

        return f
    }

    /// Check if a block label eventually reaches the header through a chain of
    /// jump-only blocks (merge blocks with no meaningful instructions).
    private func eventuallyReachesHeader(from label: String, header: String,
                                         blocks: [MIRBasicBlock],
                                         blockMap: [String: Int]) -> Bool {
        var current = label
        var visited: Set<String> = []

        while current != header {
            if visited.contains(current) { return false } // cycle without reaching header
            visited.insert(current)

            guard let idx = blockMap[current] else { return false }
            let block = blocks[idx]

            // The block should be "empty" — only const/store instructions that don't
            // affect control flow, and a jump terminator
            guard case .jump(let next) = block.terminator else { return false }

            // Allow blocks with no instructions or only stores/consts (not calls)
            let hasNonTrivialWork = block.instructions.contains { inst in
                switch inst {
                case .constInt, .constFloat, .constBool, .constString, .constNull,
                     .store, .load, .alloc:
                    return false
                default:
                    return true
                }
            }
            if hasNonTrivialWork { return false }

            current = next
        }
        return true
    }
}
