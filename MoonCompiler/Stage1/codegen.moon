// codegen.moon — Stage 1 Code Generator (self-hosted)
// Compiles AST (from parser.moon) directly to Moon bytecode (.moonb format).
// Single-pass tree-walking code generator with register allocation.

// ---------------------------------------------------------------------------
// Opcodes (must match Bytecode.swift)
// ---------------------------------------------------------------------------

fun OP_CONST_INT(): Int { return 1 }
fun OP_CONST_FLOAT(): Int { return 2 }
fun OP_CONST_TRUE(): Int { return 3 }
fun OP_CONST_FALSE(): Int { return 4 }
fun OP_CONST_STRING(): Int { return 5 }
fun OP_CONST_NULL(): Int { return 6 }
fun OP_ALLOC(): Int { return 16 }
fun OP_STORE(): Int { return 17 }
fun OP_LOAD(): Int { return 18 }
fun OP_LOAD_PARAM(): Int { return 19 }
fun OP_ADD(): Int { return 32 }
fun OP_SUB(): Int { return 33 }
fun OP_MUL(): Int { return 34 }
fun OP_DIV(): Int { return 35 }
fun OP_MOD(): Int { return 36 }
fun OP_NEG(): Int { return 37 }
fun OP_EQ(): Int { return 48 }
fun OP_NEQ(): Int { return 49 }
fun OP_LT(): Int { return 50 }
fun OP_LTE(): Int { return 51 }
fun OP_GT(): Int { return 52 }
fun OP_GTE(): Int { return 53 }
fun OP_AND(): Int { return 64 }
fun OP_OR(): Int { return 65 }
fun OP_NOT(): Int { return 66 }
fun OP_CALL(): Int { return 80 }
fun OP_TRY_BEGIN(): Int { return 176 }
fun OP_TRY_END(): Int { return 177 }
fun OP_THROW(): Int { return 178 }
fun OP_RET(): Int { return 224 }
fun OP_RET_VOID(): Int { return 225 }
fun OP_JUMP(): Int { return 226 }
fun OP_BRANCH(): Int { return 227 }

// Constant pool kind tags
fun CK_STRING(): Int { return 1 }
fun CK_FUNC_NAME(): Int { return 4 }

// Type tags
fun TT_UNIT(): Int { return 0 }
fun TT_INT(): Int { return 1 }
fun TT_FLOAT64(): Int { return 5 }
fun TT_BOOL(): Int { return 7 }
fun TT_STRING(): Int { return 8 }

// ---------------------------------------------------------------------------
// Compiler state
// ---------------------------------------------------------------------------

fun makeCompiler(): Map {
    val c = mapCreate()
    mapPut(c, "pool", listCreate())        // constant pool entries: [{kind, value}]
    mapPut(c, "poolMap", mapCreate())       // dedup: "kind:value" -> index
    mapPut(c, "functions", listCreate())    // compiled functions
    mapPut(c, "errors", listCreate())
    return c
}

// Add to constant pool (deduped). Returns index.
fun addConst(c: Map, kind: Int, value: String): Int {
    val key = stringConcat(toString(kind), stringConcat(":", value))
    val existing = mapGet(mapGet(c, "poolMap"), key)
    if (existing != null) {
        return toInt(existing)
    }
    val pool = mapGet(c, "pool")
    val idx = listSize(pool)
    val entry = mapCreate()
    mapPut(entry, "kind", kind)
    mapPut(entry, "value", value)
    listAppend(pool, entry)
    mapPut(mapGet(c, "poolMap"), key, idx)
    return idx
}

fun addStringConst(c: Map, s: String): Int {
    return addConst(c, CK_STRING(), s)
}

fun addFuncName(c: Map, name: String): Int {
    return addConst(c, CK_FUNC_NAME(), name)
}

// ---------------------------------------------------------------------------
// Function compiler state
// ---------------------------------------------------------------------------

fun makeFuncState(compiler: Map, name: String, params: List): Map {
    val fs = mapCreate()
    mapPut(fs, "compiler", compiler)
    mapPut(fs, "name", name)
    mapPut(fs, "bytecode", listCreate())   // List of Int (bytes)
    mapPut(fs, "regCount", listSize(params))
    mapPut(fs, "locals", mapCreate())       // name -> register
    mapPut(fs, "params", params)
    mapPut(fs, "patches", listCreate())     // jump patches: [{offset, label}]
    mapPut(fs, "labels", mapCreate())       // label -> bytecode offset
    mapPut(fs, "labelCounter", 0)
    mapPut(fs, "loopStack", listCreate())   // [{breakLabel, continueLabel}]

    // Register params as locals
    var i: Int = 0
    while (i < listSize(params)) {
        val param = listGet(params, i)
        val pname = toString(mapGet(param, "name"))
        mapPut(mapGet(fs, "locals"), pname, i)
        i = i + 1
    }

    return fs
}

fun allocReg(fs: Map): Int {
    val r = toInt(mapGet(fs, "regCount"))
    mapPut(fs, "regCount", r + 1)
    return r
}

fun newLabel(fs: Map): String {
    val n = toInt(mapGet(fs, "labelCounter"))
    mapPut(fs, "labelCounter", n + 1)
    return stringConcat("L", toString(n))
}

fun markLabel(fs: Map, label: String): Unit {
    val offset = listSize(mapGet(fs, "bytecode"))
    mapPut(mapGet(fs, "labels"), label, offset)
}

fun currentOffset(fs: Map): Int {
    return listSize(mapGet(fs, "bytecode"))
}

// ---------------------------------------------------------------------------
// Bytecode emission helpers
// ---------------------------------------------------------------------------

fun emitByte(fs: Map, b: Int): Unit {
    listAppend(mapGet(fs, "bytecode"), b)
}

fun emitU16(fs: Map, v: Int): Unit {
    // Big-endian UInt16
    emitByte(fs, (v / 256) % 256)
    emitByte(fs, v % 256)
}

fun emitU32(fs: Map, v: Int): Unit {
    // Big-endian UInt32
    emitByte(fs, (v / 16777216) % 256)
    emitByte(fs, (v / 65536) % 256)
    emitByte(fs, (v / 256) % 256)
    emitByte(fs, v % 256)
}

fun emitU32At(fs: Map, offset: Int, v: Int): Unit {
    val bc = mapGet(fs, "bytecode")
    listSet(bc, offset, (v / 16777216) % 256)
    listSet(bc, offset + 1, (v / 65536) % 256)
    listSet(bc, offset + 2, (v / 256) % 256)
    listSet(bc, offset + 3, v % 256)
}

fun emitI64(fs: Map, v: Int): Unit {
    // Big-endian Int64 — for simplicity handle positive values
    // For negative: two's complement
    if (v >= 0) {
        emitU32(fs, 0)
        emitU32(fs, v)
    } else {
        // Negative: all 1s in high word, value in low word (simplified)
        emitU32(fs, 4294967295)
        emitU32(fs, 4294967296 + v)
    }
}

// Emit a placeholder U32 and return offset for later patching
fun emitU32Placeholder(fs: Map): Int {
    val offset = currentOffset(fs)
    emitU32(fs, 0)
    return offset
}

// ---------------------------------------------------------------------------
// Instruction emitters
// ---------------------------------------------------------------------------

fun emitConstInt(fs: Map, dest: Int, value: Int): Unit {
    emitByte(fs, OP_CONST_INT())
    emitU16(fs, dest)
    emitI64(fs, value)
}

fun emitConstString(fs: Map, dest: Int, value: String): Unit {
    val idx = addStringConst(mapGet(fs, "compiler"), value)
    emitByte(fs, OP_CONST_STRING())
    emitU16(fs, dest)
    emitU16(fs, idx)
}

fun emitConstTrue(fs: Map, dest: Int): Unit {
    emitByte(fs, OP_CONST_TRUE())
    emitU16(fs, dest)
}

fun emitConstFalse(fs: Map, dest: Int): Unit {
    emitByte(fs, OP_CONST_FALSE())
    emitU16(fs, dest)
}

fun emitConstNull(fs: Map, dest: Int): Unit {
    emitByte(fs, OP_CONST_NULL())
    emitU16(fs, dest)
}

fun emitStore(fs: Map, dest: Int, src: Int): Unit {
    emitByte(fs, OP_STORE())
    emitU16(fs, dest)
    emitU16(fs, src)
}

fun emitLoad(fs: Map, dest: Int, src: Int): Unit {
    emitByte(fs, OP_LOAD())
    emitU16(fs, dest)
    emitU16(fs, src)
}

fun emitLoadParam(fs: Map, dest: Int, paramIdx: Int): Unit {
    emitByte(fs, OP_LOAD_PARAM())
    emitU16(fs, dest)
    emitU16(fs, paramIdx)
}

fun emitCall(fs: Map, dest: Int, funcName: String, args: List): Unit {
    val idx = addFuncName(mapGet(fs, "compiler"), funcName)
    emitByte(fs, OP_CALL())
    emitU16(fs, dest)
    emitU16(fs, idx)
    emitU16(fs, listSize(args))
    var i: Int = 0
    while (i < listSize(args)) {
        emitU16(fs, toInt(listGet(args, i)))
        i = i + 1
    }
}

fun emitBinaryOp(fs: Map, op: String, dest: Int, left: Int, right: Int): Unit {
    if (op == "+") { emitByte(fs, OP_ADD()) }
    else { if (op == "-") { emitByte(fs, OP_SUB()) }
    else { if (op == "*") { emitByte(fs, OP_MUL()) }
    else { if (op == "/") { emitByte(fs, OP_DIV()) }
    else { if (op == "%") { emitByte(fs, OP_MOD()) }
    else { if (op == "==") { emitByte(fs, OP_EQ()) }
    else { if (op == "!=") { emitByte(fs, OP_NEQ()) }
    else { if (op == "<") { emitByte(fs, OP_LT()) }
    else { if (op == "<=") { emitByte(fs, OP_LTE()) }
    else { if (op == ">") { emitByte(fs, OP_GT()) }
    else { if (op == ">=") { emitByte(fs, OP_GTE()) }
    else { if (op == "&&") { emitByte(fs, OP_AND()) }
    else { if (op == "||") { emitByte(fs, OP_OR()) }
    else {
        // Unknown operator — emit ADD as fallback
        emitByte(fs, OP_ADD())
    } } } } } } } } } } } } }
    emitU16(fs, dest)
    emitU16(fs, left)
    emitU16(fs, right)
}

fun emitRet(fs: Map, reg: Int): Unit {
    emitByte(fs, OP_RET())
    emitU16(fs, reg)
}

fun emitRetVoid(fs: Map): Unit {
    emitByte(fs, OP_RET_VOID())
}

fun emitJump(fs: Map): Int {
    emitByte(fs, OP_JUMP())
    val offset = currentOffset(fs)
    emitU32(fs, 0)  // placeholder
    return offset
}

fun emitBranch(fs: Map, condReg: Int): Map {
    emitByte(fs, OP_BRANCH())
    emitU16(fs, condReg)
    val thenOffset = currentOffset(fs)
    emitU32(fs, 0)  // then placeholder
    val elseOffset = currentOffset(fs)
    emitU32(fs, 0)  // else placeholder
    val result = mapCreate()
    mapPut(result, "thenPatch", thenOffset)
    mapPut(result, "elsePatch", elseOffset)
    return result
}

fun patchJump(fs: Map, patchOffset: Int): Unit {
    emitU32At(fs, patchOffset, currentOffset(fs))
}

// ---------------------------------------------------------------------------
// Expression compilation — returns the register holding the result
// ---------------------------------------------------------------------------

fun compileExpr(fs: Map, node: Map): Int {
    val kind = toString(mapGet(node, "kind"))

    if (kind == "intLit") {
        val dest = allocReg(fs)
        val value = toInt(mapGet(node, "value"))
        emitConstInt(fs, dest, value)
        return dest
    }

    if (kind == "floatLit") {
        // Emit as int for now (float codegen would need emitF64)
        val dest = allocReg(fs)
        emitConstInt(fs, dest, 0)
        return dest
    }

    if (kind == "stringLit") {
        val dest = allocReg(fs)
        emitConstString(fs, dest, toString(mapGet(node, "value")))
        return dest
    }

    if (kind == "boolLit") {
        val dest = allocReg(fs)
        if (mapGet(node, "value") == true) {
            emitConstTrue(fs, dest)
        } else {
            emitConstFalse(fs, dest)
        }
        return dest
    }

    if (kind == "nullLit") {
        val dest = allocReg(fs)
        emitConstNull(fs, dest)
        return dest
    }

    if (kind == "ident") {
        val name = toString(mapGet(node, "name"))
        val locals = mapGet(fs, "locals")
        val reg = mapGet(locals, name)
        if (reg != null) {
            // Load from local variable's alloc slot
            val dest = allocReg(fs)
            emitLoad(fs, dest, toInt(reg))
            return dest
        }
        // Unknown identifier — might be a function reference
        val dest = allocReg(fs)
        emitConstString(fs, dest, name)
        return dest
    }

    if (kind == "binary") {
        val op = toString(mapGet(node, "op"))
        val leftReg = compileExpr(fs, mapGet(node, "left"))
        val rightReg = compileExpr(fs, mapGet(node, "right"))
        val dest = allocReg(fs)
        emitBinaryOp(fs, op, dest, leftReg, rightReg)
        return dest
    }

    if (kind == "unary") {
        val op = toString(mapGet(node, "op"))
        val operandReg = compileExpr(fs, mapGet(node, "operand"))
        val dest = allocReg(fs)
        if (op == "-") {
            emitByte(fs, OP_NEG())
            emitU16(fs, dest)
            emitU16(fs, operandReg)
        } else {
            if (op == "!") {
                emitByte(fs, OP_NOT())
                emitU16(fs, dest)
                emitU16(fs, operandReg)
            }
        }
        return dest
    }

    if (kind == "call") {
        val callee = mapGet(node, "callee")
        val calleeKind = toString(mapGet(callee, "kind"))
        val callArgs = mapGet(node, "args")

        // Simple function call: funcName(args)
        if (calleeKind == "ident") {
            val funcName = toString(mapGet(callee, "name"))
            val argRegs = listCreate()
            var i: Int = 0
            while (i < listSize(callArgs)) {
                val argNode = listGet(callArgs, i)
                // Handle named args
                val argKind = toString(mapGet(argNode, "kind"))
                if (argKind == "namedArg") {
                    listAppend(argRegs, compileExpr(fs, mapGet(argNode, "value")))
                } else {
                    listAppend(argRegs, compileExpr(fs, argNode))
                }
                i = i + 1
            }
            val dest = allocReg(fs)
            emitCall(fs, dest, funcName, argRegs)
            return dest
        }

        // Method call: obj.method(args) — compile as regular call for now
        if (calleeKind == "member") {
            val objReg = compileExpr(fs, mapGet(callee, "object"))
            val methodName = toString(mapGet(callee, "name"))
            val argRegs = listCreate()
            listAppend(argRegs, objReg)
            var i: Int = 0
            while (i < listSize(callArgs)) {
                listAppend(argRegs, compileExpr(fs, listGet(callArgs, i)))
                i = i + 1
            }
            val dest = allocReg(fs)
            emitCall(fs, dest, methodName, argRegs)
            return dest
        }

        // Fallback: indirect call
        val funcReg = compileExpr(fs, callee)
        val argRegs = listCreate()
        var i: Int = 0
        while (i < listSize(callArgs)) {
            listAppend(argRegs, compileExpr(fs, listGet(callArgs, i)))
            i = i + 1
        }
        val dest = allocReg(fs)
        emitCall(fs, dest, "??", argRegs)
        return dest
    }

    if (kind == "if") {
        return compileIfExpr(fs, node)
    }

    if (kind == "when") {
        return compileWhenExpr(fs, node)
    }

    // Fallback: emit null
    val dest = allocReg(fs)
    emitConstNull(fs, dest)
    return dest
}

// ---------------------------------------------------------------------------
// If expression compilation
// ---------------------------------------------------------------------------

fun compileIfExpr(fs: Map, node: Map): Int {
    val condReg = compileExpr(fs, mapGet(node, "condition"))
    val patches = emitBranch(fs, condReg)

    // Then branch
    patchJump(fs, toInt(mapGet(patches, "thenPatch")))
    compileBlock(fs, mapGet(node, "then"))
    val jumpToEnd = emitJump(fs)

    // Else branch
    patchJump(fs, toInt(mapGet(patches, "elsePatch")))
    val elseNode = mapGet(node, "else")
    if (elseNode != null) {
        val elseKind = toString(mapGet(elseNode, "kind"))
        if (elseKind == "block") {
            compileBlock(fs, elseNode)
        } else {
            if (elseKind == "if") {
                compileIfExpr(fs, elseNode)
            } else {
                compileStmt(fs, elseNode)
            }
        }
    }

    // End
    patchJump(fs, jumpToEnd)
    val dest = allocReg(fs)
    emitConstNull(fs, dest)
    return dest
}

// ---------------------------------------------------------------------------
// When expression compilation
// ---------------------------------------------------------------------------

fun compileWhenExpr(fs: Map, node: Map): Int {
    val subject = mapGet(node, "subject")
    var subjectReg: Int = 0
    if (subject != null) {
        subjectReg = compileExpr(fs, subject)
    }

    val branches = mapGet(node, "branches")
    val endPatches = listCreate()
    var i: Int = 0
    while (i < listSize(branches)) {
        val branch = listGet(branches, i)
        val isElse = mapGet(branch, "isElse")

        if (isElse == true) {
            // Else branch — always execute
            val body = mapGet(branch, "body")
            val bodyKind = toString(mapGet(body, "kind"))
            if (bodyKind == "block") {
                compileBlock(fs, body)
            } else {
                compileExpr(fs, body)
            }
        } else {
            // Pattern matching branch
            val patterns = mapGet(branch, "patterns")
            val patternReg = compileExpr(fs, listGet(patterns, 0))
            val condReg = allocReg(fs)
            emitBinaryOp(fs, "==", condReg, subjectReg, patternReg)
            val patches = emitBranch(fs, condReg)
            patchJump(fs, toInt(mapGet(patches, "thenPatch")))

            val body = mapGet(branch, "body")
            val bodyKind = toString(mapGet(body, "kind"))
            if (bodyKind == "block") {
                compileBlock(fs, body)
            } else {
                compileExpr(fs, body)
            }
            listAppend(endPatches, emitJump(fs))

            patchJump(fs, toInt(mapGet(patches, "elsePatch")))
        }
        i = i + 1
    }

    // Patch all end jumps
    var j: Int = 0
    while (j < listSize(endPatches)) {
        patchJump(fs, toInt(listGet(endPatches, j)))
        j = j + 1
    }

    val dest = allocReg(fs)
    emitConstNull(fs, dest)
    return dest
}

// ---------------------------------------------------------------------------
// Statement compilation
// ---------------------------------------------------------------------------

fun compileStmt(fs: Map, node: Map): Unit {
    val kind = toString(mapGet(node, "kind"))

    if (kind == "valDecl" || kind == "varDecl") {
        val name = toString(mapGet(node, "name"))
        val slot = allocReg(fs)
        mapPut(mapGet(fs, "locals"), name, slot)
        val initNode = mapGet(node, "init")
        if (initNode != null) {
            val initReg = compileExpr(fs, initNode)
            emitStore(fs, slot, initReg)
        }
        return
    }

    if (kind == "assign") {
        val target = mapGet(node, "target")
        val targetKind = toString(mapGet(target, "kind"))
        if (targetKind == "ident") {
            val name = toString(mapGet(target, "name"))
            val slot = mapGet(mapGet(fs, "locals"), name)
            if (slot != null) {
                val valueReg = compileExpr(fs, mapGet(node, "value"))
                emitStore(fs, toInt(slot), valueReg)
            }
        }
        return
    }

    if (kind == "compoundAssign") {
        val target = mapGet(node, "target")
        val targetKind = toString(mapGet(target, "kind"))
        if (targetKind == "ident") {
            val name = toString(mapGet(target, "name"))
            val slot = mapGet(mapGet(fs, "locals"), name)
            if (slot != null) {
                val slotInt = toInt(slot)
                val currentReg = allocReg(fs)
                emitLoad(fs, currentReg, slotInt)
                val valueReg = compileExpr(fs, mapGet(node, "value"))
                val op = toString(mapGet(node, "op"))
                var actualOp: String = "+"
                if (op == "+=") { actualOp = "+" }
                if (op == "-=") { actualOp = "-" }
                if (op == "*=") { actualOp = "*" }
                if (op == "/=") { actualOp = "/" }
                if (op == "%=") { actualOp = "%" }
                val resultReg = allocReg(fs)
                emitBinaryOp(fs, actualOp, resultReg, currentReg, valueReg)
                emitStore(fs, slotInt, resultReg)
            }
        }
        return
    }

    if (kind == "return") {
        val valueNode = mapGet(node, "value")
        if (valueNode != null) {
            val reg = compileExpr(fs, valueNode)
            emitRet(fs, reg)
        } else {
            emitRetVoid(fs)
        }
        return
    }

    if (kind == "throw") {
        val reg = compileExpr(fs, mapGet(node, "value"))
        emitByte(fs, OP_THROW())
        emitU16(fs, reg)
        return
    }

    if (kind == "if") {
        compileIfExpr(fs, node)
        return
    }

    if (kind == "while") {
        val loopStart = currentOffset(fs)
        val breakLabel = newLabel(fs)
        val continueLabel = newLabel(fs)

        // Push loop context
        val loopCtx = mapCreate()
        mapPut(loopCtx, "breakLabel", breakLabel)
        mapPut(loopCtx, "continueLabel", continueLabel)
        listAppend(mapGet(fs, "loopStack"), loopCtx)

        // Condition
        markLabel(fs, continueLabel)
        val condReg = compileExpr(fs, mapGet(node, "condition"))
        val patches = emitBranch(fs, condReg)
        patchJump(fs, toInt(mapGet(patches, "thenPatch")))

        // Body
        compileBlock(fs, mapGet(node, "body"))

        // Loop back
        emitByte(fs, OP_JUMP())
        emitU32(fs, loopStart)

        // Exit
        patchJump(fs, toInt(mapGet(patches, "elsePatch")))
        markLabel(fs, breakLabel)

        // Pop loop context
        val stack = mapGet(fs, "loopStack")
        listRemoveAt(stack, listSize(stack) - 1)
        return
    }

    if (kind == "for") {
        // for (variable in iterable) { body }
        // Compile as: val list = iterable; var i = 0; while (i < listSize(list)) { val variable = listGet(list, i); body; i = i + 1 }
        val varName = toString(mapGet(node, "variable"))
        val iterReg = compileExpr(fs, mapGet(node, "iterable"))

        // Size
        val sizeArgs = listCreate()
        listAppend(sizeArgs, iterReg)
        val sizeReg = allocReg(fs)
        emitCall(fs, sizeReg, "listSize", sizeArgs)

        // Index counter
        val indexSlot = allocReg(fs)
        val zeroReg = allocReg(fs)
        emitConstInt(fs, zeroReg, 0)
        emitStore(fs, indexSlot, zeroReg)

        val loopStart = currentOffset(fs)
        val breakLabel = newLabel(fs)
        val continueLabel = newLabel(fs)

        val loopCtx = mapCreate()
        mapPut(loopCtx, "breakLabel", breakLabel)
        mapPut(loopCtx, "continueLabel", continueLabel)
        listAppend(mapGet(fs, "loopStack"), loopCtx)

        // Condition: index < size
        markLabel(fs, continueLabel)
        val idxLoadReg = allocReg(fs)
        emitLoad(fs, idxLoadReg, indexSlot)
        val condReg = allocReg(fs)
        emitBinaryOp(fs, "<", condReg, idxLoadReg, sizeReg)
        val patches = emitBranch(fs, condReg)
        patchJump(fs, toInt(mapGet(patches, "thenPatch")))

        // Get element
        val getArgs = listCreate()
        listAppend(getArgs, iterReg)
        val idxReg2 = allocReg(fs)
        emitLoad(fs, idxReg2, indexSlot)
        listAppend(getArgs, idxReg2)
        val elemReg = allocReg(fs)
        emitCall(fs, elemReg, "listGet", getArgs)

        // Bind loop variable
        val elemSlot = allocReg(fs)
        emitStore(fs, elemSlot, elemReg)
        mapPut(mapGet(fs, "locals"), varName, elemSlot)

        // Body
        compileBlock(fs, mapGet(node, "body"))

        // Increment
        val curIdx = allocReg(fs)
        emitLoad(fs, curIdx, indexSlot)
        val oneReg = allocReg(fs)
        emitConstInt(fs, oneReg, 1)
        val newIdx = allocReg(fs)
        emitBinaryOp(fs, "+", newIdx, curIdx, oneReg)
        emitStore(fs, indexSlot, newIdx)

        // Loop back
        emitByte(fs, OP_JUMP())
        emitU32(fs, loopStart)

        // Exit
        patchJump(fs, toInt(mapGet(patches, "elsePatch")))
        markLabel(fs, breakLabel)

        val stack = mapGet(fs, "loopStack")
        listRemoveAt(stack, listSize(stack) - 1)
        return
    }

    if (kind == "break") {
        val stack = mapGet(fs, "loopStack")
        if (listSize(stack) > 0) {
            val ctx = listGet(stack, listSize(stack) - 1)
            val label = toString(mapGet(ctx, "breakLabel"))
            val labelOffset = mapGet(mapGet(fs, "labels"), label)
            if (labelOffset != null) {
                emitByte(fs, OP_JUMP())
                emitU32(fs, toInt(labelOffset))
            } else {
                // Forward jump — need to patch later
                emitByte(fs, OP_JUMP())
                val patchOff = currentOffset(fs)
                emitU32(fs, 0)
                val patchEntry = mapCreate()
                mapPut(patchEntry, "offset", patchOff)
                mapPut(patchEntry, "label", label)
                listAppend(mapGet(fs, "patches"), patchEntry)
            }
        }
        return
    }

    if (kind == "continue") {
        val stack = mapGet(fs, "loopStack")
        if (listSize(stack) > 0) {
            val ctx = listGet(stack, listSize(stack) - 1)
            val label = toString(mapGet(ctx, "continueLabel"))
            val labelOffset = mapGet(mapGet(fs, "labels"), label)
            if (labelOffset != null) {
                emitByte(fs, OP_JUMP())
                emitU32(fs, toInt(labelOffset))
            } else {
                emitByte(fs, OP_JUMP())
                val patchOff = currentOffset(fs)
                emitU32(fs, 0)
                val patchEntry = mapCreate()
                mapPut(patchEntry, "offset", patchOff)
                mapPut(patchEntry, "label", label)
                listAppend(mapGet(fs, "patches"), patchEntry)
            }
        }
        return
    }

    if (kind == "tryCatch") {
        // TRY_BEGIN with catch offset, exception register
        val excSlot = allocReg(fs)
        emitByte(fs, OP_TRY_BEGIN())
        val catchPatch = currentOffset(fs)
        emitU32(fs, 0)  // catch offset placeholder
        emitU16(fs, excSlot)

        // Try body
        compileBlock(fs, mapGet(node, "tryBody"))
        emitByte(fs, OP_TRY_END())
        val jumpToEnd = emitJump(fs)

        // Catch block
        patchJump(fs, catchPatch)
        val catchVar = mapGet(node, "catchVar")
        if (catchVar != null) {
            mapPut(mapGet(fs, "locals"), toString(catchVar), excSlot)
        }
        val catchBody = mapGet(node, "catchBody")
        if (catchBody != null) {
            compileBlock(fs, catchBody)
        }

        patchJump(fs, jumpToEnd)
        return
    }

    if (kind == "when") {
        compileWhenExpr(fs, node)
        return
    }

    // Expression statement
    compileExpr(fs, node)
}

fun compileBlock(fs: Map, blockNode: Map): Unit {
    val kind = toString(mapGet(blockNode, "kind"))
    if (kind == "block") {
        val stmts = mapGet(blockNode, "stmts")
        var i: Int = 0
        while (i < listSize(stmts)) {
            compileStmt(fs, listGet(stmts, i))
            i = i + 1
        }
    } else {
        compileStmt(fs, blockNode)
    }
}

// ---------------------------------------------------------------------------
// Function compilation
// ---------------------------------------------------------------------------

fun compileFunction(compiler: Map, decl: Map): Unit {
    val name = toString(mapGet(decl, "name"))
    val params = mapGet(decl, "params")
    if (params == null) { return }

    val nameIdx = addFuncName(compiler, name)
    val fs = makeFuncState(compiler, name, params)

    // Load params into alloc slots
    var i: Int = 0
    while (i < listSize(params)) {
        val paramReg = allocReg(fs)
        emitLoadParam(fs, paramReg, i)
        val pname = toString(mapGet(listGet(params, i), "name"))
        val slot = allocReg(fs)
        emitStore(fs, slot, paramReg)
        mapPut(mapGet(fs, "locals"), pname, slot)
        i = i + 1
    }

    // Compile body
    val body = mapGet(decl, "body")
    if (body != null) {
        compileBlock(fs, body)
    }

    // Ensure function ends with ret
    val bc = mapGet(fs, "bytecode")
    val bcLen = listSize(bc)
    if (bcLen == 0 || toInt(listGet(bc, bcLen - 1)) != OP_RET_VOID()) {
        // Check if last instruction was a RET
        var needsRet: Bool = true
        if (bcLen >= 3) {
            val lastOpOffset = bcLen - 3
            if (toInt(listGet(bc, lastOpOffset)) == OP_RET()) {
                needsRet = false
            }
        }
        if (bcLen >= 1) {
            if (toInt(listGet(bc, bcLen - 1)) == OP_RET_VOID()) {
                needsRet = false
            }
        }
        if (needsRet) {
            emitRetVoid(fs)
        }
    }

    // Resolve patches
    val patches = mapGet(fs, "patches")
    var pi: Int = 0
    while (pi < listSize(patches)) {
        val patch = listGet(patches, pi)
        val patchOff = toInt(mapGet(patch, "offset"))
        val label = toString(mapGet(patch, "label"))
        val target = mapGet(mapGet(fs, "labels"), label)
        if (target != null) {
            emitU32At(fs, patchOff, toInt(target))
        }
        pi = pi + 1
    }

    // Build function record
    val funcRec = mapCreate()
    mapPut(funcRec, "nameIdx", nameIdx)
    mapPut(funcRec, "paramCount", listSize(params))
    mapPut(funcRec, "regCount", toInt(mapGet(fs, "regCount")))
    mapPut(funcRec, "bytecode", bc)
    mapPut(funcRec, "params", params)

    // Determine return type tag
    val retType = mapGet(decl, "returnType")
    if (retType != null) {
        val typeName = toString(mapGet(retType, "name"))
        if (typeName == "Unit") { mapPut(funcRec, "returnTag", TT_UNIT()) }
        else { if (typeName == "Int") { mapPut(funcRec, "returnTag", TT_INT()) }
        else { if (typeName == "String") { mapPut(funcRec, "returnTag", TT_STRING()) }
        else { if (typeName == "Bool") { mapPut(funcRec, "returnTag", TT_BOOL()) }
        else { if (typeName == "Float64") { mapPut(funcRec, "returnTag", TT_FLOAT64()) }
        else { mapPut(funcRec, "returnTag", TT_UNIT()) } } } } }
    } else {
        mapPut(funcRec, "returnTag", TT_UNIT())
    }

    listAppend(mapGet(compiler, "functions"), funcRec)
}

// ---------------------------------------------------------------------------
// Binary serialization (.moonb format)
// ---------------------------------------------------------------------------

fun serializeModule(compiler: Map): List {
    val bytes = listCreate()

    // Magic: "MOON"
    listAppend(bytes, 77)   // M
    listAppend(bytes, 79)   // O
    listAppend(bytes, 79)   // O
    listAppend(bytes, 78)   // N

    // Version 1.0
    appendU16(bytes, 1)
    appendU16(bytes, 0)

    // Constant pool
    val pool = mapGet(compiler, "pool")
    appendU32(bytes, listSize(pool))
    var i: Int = 0
    while (i < listSize(pool)) {
        val entry = listGet(pool, i)
        val kind = toInt(mapGet(entry, "kind"))
        val value = toString(mapGet(entry, "value"))
        listAppend(bytes, kind)
        val strBytes = stringToBytes(value)
        appendU32(bytes, listSize(strBytes))
        var j: Int = 0
        while (j < listSize(strBytes)) {
            listAppend(bytes, toInt(listGet(strBytes, j)))
            j = j + 1
        }
        i = i + 1
    }

    // Globals: 0
    appendU32(bytes, 0)

    // Types: 0
    appendU32(bytes, 0)

    // Functions
    val funcs = mapGet(compiler, "functions")
    appendU32(bytes, listSize(funcs))
    var fi: Int = 0
    while (fi < listSize(funcs)) {
        val func = listGet(funcs, fi)
        appendU16(bytes, toInt(mapGet(func, "nameIdx")))
        val paramCount = toInt(mapGet(func, "paramCount"))
        appendU16(bytes, paramCount)
        appendU16(bytes, toInt(mapGet(func, "regCount")))
        listAppend(bytes, toInt(mapGet(func, "returnTag")))

        // Parameter info
        val funcParams = mapGet(func, "params")
        var pi: Int = 0
        while (pi < paramCount) {
            val param = listGet(funcParams, pi)
            val pname = toString(mapGet(param, "name"))
            val pnameIdx = addConst(compiler, 7, pname)
            appendU16(bytes, pnameIdx)
            // Type tag — default to int
            val ptype = mapGet(param, "type")
            if (ptype != null) {
                val ptypeName = toString(mapGet(ptype, "name"))
                if (ptypeName == "Int") { listAppend(bytes, TT_INT()) }
                else { if (ptypeName == "String") { listAppend(bytes, TT_STRING()) }
                else { if (ptypeName == "Bool") { listAppend(bytes, TT_BOOL()) }
                else { listAppend(bytes, TT_UNIT()) } } }
            } else {
                listAppend(bytes, TT_UNIT())
            }
            pi = pi + 1
        }

        // Bytecode
        val bc = mapGet(func, "bytecode")
        appendU32(bytes, listSize(bc))
        var bi: Int = 0
        while (bi < listSize(bc)) {
            listAppend(bytes, toInt(listGet(bc, bi)))
            bi = bi + 1
        }
        fi = fi + 1
    }

    return bytes
}

fun appendU16(bytes: List, v: Int): Unit {
    listAppend(bytes, (v / 256) % 256)
    listAppend(bytes, v % 256)
}

fun appendU32(bytes: List, v: Int): Unit {
    listAppend(bytes, (v / 16777216) % 256)
    listAppend(bytes, (v / 65536) % 256)
    listAppend(bytes, (v / 256) % 256)
    listAppend(bytes, v % 256)
}

fun stringToBytes(s: String): List {
    val result = listCreate()
    val len = stringLength(s)
    var i: Int = 0
    while (i < len) {
        listAppend(result, charCodeAt(s, i))
        i = i + 1
    }
    return result
}

// ---------------------------------------------------------------------------
// Main entry point
// ---------------------------------------------------------------------------

fun compileProgram(ast: Map): Map {
    val compiler = makeCompiler()
    val decls = mapGet(ast, "decls")
    var i: Int = 0
    while (i < listSize(decls)) {
        val decl = listGet(decls, i)
        val kind = toString(mapGet(decl, "kind"))
        if (kind == "funDecl") {
            compileFunction(compiler, decl)
        }
        i = i + 1
    }
    return compiler
}

fun main(): Unit {
    val args = processArgs()
    if (listSize(args) < 2) {
        println("Usage: moonc <source.moon> [output.moonb]")
        println("       moonc run <source.moon>")
        return
    }

    val command = toString(listGet(args, 0))
    var sourceFile: String = toString(listGet(args, 1))
    var outputFile: String = ""

    // Determine output file
    if (listSize(args) > 2) {
        outputFile = toString(listGet(args, 2))
    } else {
        // Replace .moon with .moonb
        val len = stringLength(sourceFile)
        if (endsWith(sourceFile, ".moon")) {
            outputFile = stringConcat(substring(sourceFile, 0, len - 5), ".moonb")
        } else {
            outputFile = stringConcat(sourceFile, ".moonb")
        }
    }

    // Read source
    val source = toString(fileRead(sourceFile))

    // Lex
    val tokens = tokenize(source)

    // Parse
    val parser = makeParser(tokens)
    val ast = parseProgram(parser)

    // Check for parse errors
    val errors = mapGet(parser, "errors")
    if (listSize(errors) > 0) {
        println(stringConcat(toString(listSize(errors)), " parse error(s):"))
        var i: Int = 0
        while (i < listSize(errors)) {
            println(stringConcat("  ", toString(listGet(errors, i))))
            i = i + 1
        }
        return
    }

    // Compile
    val compiler = compileProgram(ast)

    // Serialize
    val moduleBytes = serializeModule(compiler)

    // Write
    fileWriteBytes(outputFile, moduleBytes)

    val funcCount = listSize(mapGet(compiler, "functions"))
    val byteCount = listSize(moduleBytes)
    println(stringConcat(sourceFile, stringConcat(" -> ", outputFile)))
    println(stringConcat("  ", stringConcat(toString(funcCount), stringConcat(" function(s), ", stringConcat(toString(byteCount), " bytes")))))
}
