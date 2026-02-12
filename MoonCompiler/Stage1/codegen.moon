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
fun OP_VCALL(): Int { return 81 }
fun OP_GET_FIELD(): Int { return 96 }
fun OP_SET_FIELD(): Int { return 97 }
fun OP_NEW_OBJECT(): Int { return 112 }
fun OP_CALL_INDIRECT(): Int { return 82 }
fun OP_NULL_CHECK(): Int { return 128 }
fun OP_IS_NULL(): Int { return 129 }
fun OP_TYPE_CHECK(): Int { return 144 }
fun OP_TYPE_CAST(): Int { return 145 }

// Constant pool kind tags
fun CK_STRING(): Int { return 1 }
fun CK_TYPE_NAME(): Int { return 2 }
fun CK_FIELD_NAME(): Int { return 3 }
fun CK_FUNC_NAME(): Int { return 4 }
fun CK_METHOD_NAME(): Int { return 5 }

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
    mapPut(c, "types", listCreate())        // class type records
    mapPut(c, "classNames", mapCreate())   // className -> true (set)
    mapPut(c, "enumNames", mapCreate())   // enumName -> list of entry names
    mapPut(c, "objectNames", mapCreate()) // objectName -> true (singletons)
    mapPut(c, "interfaceNames", mapCreate()) // ifaceName -> list of method names
    mapPut(c, "sealedNames", mapCreate())    // sealedName -> list of subclass names
    mapPut(c, "funcSignatures", mapCreate()) // funcName -> params list (for default args)
    mapPut(c, "typeAliases", mapCreate())    // aliasName -> targetName
    mapPut(c, "extensionFuncs", mapCreate()) // "TypeName.method" -> true
    mapPut(c, "lambdaCounter", 0)
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

fun addTypeName(c: Map, name: String): Int {
    return addConst(c, CK_TYPE_NAME(), name)
}

fun addFieldName(c: Map, name: String): Int {
    return addConst(c, CK_FIELD_NAME(), name)
}

fun addMethodName(c: Map, name: String): Int {
    return addConst(c, CK_METHOD_NAME(), name)
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
    mapPut(fs, "localFuncs", mapCreate())  // localName -> mangledName
    mapPut(fs, "lineTable", listCreate())  // [{offset, line}] pairs
    mapPut(fs, "lastLine", 0)              // last emitted line number

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

// Record a source line mapping for the current bytecode offset
fun trackLine(fs: Map, node: Map): Unit {
    val line = toInt(mapGet(node, "line"))
    if (line > 0) {
        val lastLine = toInt(mapGet(fs, "lastLine"))
        if (line != lastLine) {
            val entry = mapCreate()
            mapPut(entry, "offset", currentOffset(fs))
            mapPut(entry, "line", line)
            listAppend(mapGet(fs, "lineTable"), entry)
            mapPut(fs, "lastLine", line)
        }
    }
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

fun emitCallIndirect(fs: Map, dest: Int, funcRefReg: Int, args: List): Unit {
    emitByte(fs, OP_CALL_INDIRECT())
    emitU16(fs, dest)
    emitU16(fs, funcRefReg)
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

fun emitNewObject(fs: Map, dest: Int, typeName: String, args: List): Unit {
    val idx = addTypeName(mapGet(fs, "compiler"), typeName)
    emitByte(fs, OP_NEW_OBJECT())
    emitU16(fs, dest)
    emitU16(fs, idx)
    emitU16(fs, listSize(args))
    var i: Int = 0
    while (i < listSize(args)) {
        emitU16(fs, toInt(listGet(args, i)))
        i = i + 1
    }
}

fun emitGetField(fs: Map, dest: Int, objReg: Int, fieldName: String): Unit {
    val idx = addFieldName(mapGet(fs, "compiler"), fieldName)
    emitByte(fs, OP_GET_FIELD())
    emitU16(fs, dest)
    emitU16(fs, objReg)
    emitU16(fs, idx)
}

fun emitSetField(fs: Map, objReg: Int, fieldName: String, valueReg: Int): Unit {
    val idx = addFieldName(mapGet(fs, "compiler"), fieldName)
    emitByte(fs, OP_SET_FIELD())
    emitU16(fs, objReg)
    emitU16(fs, idx)
    emitU16(fs, valueReg)
}

fun emitVcall(fs: Map, dest: Int, objReg: Int, methodName: String, args: List): Unit {
    val idx = addMethodName(mapGet(fs, "compiler"), methodName)
    emitByte(fs, OP_VCALL())
    emitU16(fs, dest)
    emitU16(fs, objReg)
    emitU16(fs, idx)
    emitU16(fs, listSize(args))
    var i: Int = 0
    while (i < listSize(args)) {
        emitU16(fs, toInt(listGet(args, i)))
        i = i + 1
    }
}

fun emitNullCheck(fs: Map, dest: Int, src: Int): Unit {
    emitByte(fs, OP_NULL_CHECK())
    emitU16(fs, dest)
    emitU16(fs, src)
}

fun emitIsNull(fs: Map, dest: Int, src: Int): Unit {
    emitByte(fs, OP_IS_NULL())
    emitU16(fs, dest)
    emitU16(fs, src)
}

fun emitTypeCheck(fs: Map, dest: Int, src: Int, typeName: String): Unit {
    val idx = addTypeName(mapGet(fs, "compiler"), typeName)
    emitByte(fs, OP_TYPE_CHECK())
    emitU16(fs, dest)
    emitU16(fs, src)
    emitU16(fs, idx)
}

fun emitTypeCast(fs: Map, dest: Int, src: Int, typeName: String): Unit {
    val idx = addTypeName(mapGet(fs, "compiler"), typeName)
    emitByte(fs, OP_TYPE_CAST())
    emitU16(fs, dest)
    emitU16(fs, src)
    emitU16(fs, idx)
}

// ---------------------------------------------------------------------------
// String interpolation helper
// ---------------------------------------------------------------------------

fun isIdentCodePoint(code: Int): Bool {
    // a-z, A-Z, 0-9, _
    if (code >= 97 && code <= 122) { return true }
    if (code >= 65 && code <= 90) { return true }
    if (code >= 48 && code <= 57) { return true }
    if (code == 95) { return true }
    return false
}

fun compileStringInterp(fs: Map, raw: String): Int {
    val parts = listCreate()  // [{type:"lit"/"expr", value:"..."}]
    val len = stringLength(raw)
    var i: Int = 0
    var current: String = ""

    while (i < len) {
        val ch = charAt(raw, i)
        if (ch == "$" && i + 1 < len) {
            val next = charAt(raw, i + 1)
            if (next == "{") {
                // Save literal part
                if (stringLength(current) > 0) {
                    val p = mapCreate()
                    mapPut(p, "type", "lit")
                    mapPut(p, "value", current)
                    listAppend(parts, p)
                    current = ""
                }
                // Extract expression text
                i = i + 2
                var expr: String = ""
                var depth: Int = 1
                while (i < len && depth > 0) {
                    val ec = charAt(raw, i)
                    if (ec == "{") { depth = depth + 1 }
                    if (ec == "}") { depth = depth - 1 }
                    if (depth > 0) {
                        expr = stringConcat(expr, ec)
                    }
                    i = i + 1
                }
                val p = mapCreate()
                mapPut(p, "type", "expr")
                mapPut(p, "value", expr)
                listAppend(parts, p)
            } else {
                // $identifier
                if (stringLength(current) > 0) {
                    val p = mapCreate()
                    mapPut(p, "type", "lit")
                    mapPut(p, "value", current)
                    listAppend(parts, p)
                    current = ""
                }
                i = i + 1
                var ident: String = ""
                while (i < len) {
                    if (!isIdentCodePoint(charCodeAt(raw, i))) {
                        break
                    }
                    ident = stringConcat(ident, charAt(raw, i))
                    i = i + 1
                }
                val p = mapCreate()
                mapPut(p, "type", "expr")
                mapPut(p, "value", ident)
                listAppend(parts, p)
            }
        } else {
            current = stringConcat(current, ch)
            i = i + 1
        }
    }
    if (stringLength(current) > 0) {
        val p = mapCreate()
        mapPut(p, "type", "lit")
        mapPut(p, "value", current)
        listAppend(parts, p)
    }

    // Generate code: concatenate all parts
    var resultReg: Int = -1
    var pi: Int = 0
    while (pi < listSize(parts)) {
        val part = listGet(parts, pi)
        val ptype = toString(mapGet(part, "type"))
        val pvalue = toString(mapGet(part, "value"))
        var partReg: Int = 0

        if (ptype == "lit") {
            partReg = allocReg(fs)
            emitConstString(fs, partReg, pvalue)
        } else {
            // Expression: tokenize, parse, and compile
            val exprTokens = tokenize(pvalue)
            val exprParser = makeParser(exprTokens)
            val exprNode = parseExpression(exprParser, 0)
            val valueReg = compileExpr(fs, exprNode)
            // toString the value
            val toStrArgs = listCreate()
            listAppend(toStrArgs, valueReg)
            partReg = allocReg(fs)
            emitCall(fs, partReg, "toString", toStrArgs)
        }

        if (resultReg == -1) {
            resultReg = partReg
        } else {
            val concatArgs = listCreate()
            listAppend(concatArgs, resultReg)
            listAppend(concatArgs, partReg)
            val newResult = allocReg(fs)
            emitCall(fs, newResult, "stringConcat", concatArgs)
            resultReg = newResult
        }
        pi = pi + 1
    }

    if (resultReg == -1) {
        resultReg = allocReg(fs)
        emitConstString(fs, resultReg, "")
    }
    return resultReg
}

// ---------------------------------------------------------------------------
// Expression compilation — returns the register holding the result
// ---------------------------------------------------------------------------

fun compileExpr(fs: Map, node: Map): Int {
    if (mapGet(node, "line") != null) { trackLine(fs, node) }
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
        val rawStr = toString(mapGet(node, "value"))
        // Check for string interpolation
        if (stringIndexOf(rawStr, "$") >= 0) {
            return compileStringInterp(fs, rawStr)
        }
        val dest = allocReg(fs)
        emitConstString(fs, dest, rawStr)
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
        // Check if in a method and identifier is a class field
        val methodClass = mapGet(fs, "className")
        if (methodClass != null) {
            val classFields = mapGet(fs, "classFields")
            if (listContains(classFields, name)) {
                val thisSlot = toInt(mapGet(mapGet(fs, "locals"), "this"))
                val thisReg = allocReg(fs)
                emitLoad(fs, thisReg, thisSlot)
                val dest = allocReg(fs)
                emitGetField(fs, dest, thisReg, name)
                return dest
            }
        }
        // Unknown identifier — might be a function reference
        val dest = allocReg(fs)
        emitConstString(fs, dest, name)
        return dest
    }

    if (kind == "member") {
        val obj = mapGet(node, "object")
        val fieldName = toString(mapGet(node, "name"))
        // Check if this is an enum member access: EnumName.ENTRY
        val objKind = toString(mapGet(obj, "kind"))
        if (objKind == "ident") {
            val objName = toString(mapGet(obj, "name"))
            val enumEntries = mapGet(mapGet(mapGet(fs, "compiler"), "enumNames"), objName)
            if (enumEntries != null) {
                // Enum access → call initializer function
                val dest = allocReg(fs)
                val initName = stringConcat("__init_", stringConcat(objName, stringConcat("_", fieldName)))
                emitCall(fs, dest, initName, listCreate())
                return dest
            }
        }
        val objReg = compileExpr(fs, obj)
        val dest = allocReg(fs)
        emitGetField(fs, dest, objReg, fieldName)
        return dest
    }

    // Null-safe member access: obj?.member
    // If obj is null → result is null; otherwise → GET_FIELD
    if (kind == "nullSafeMember") {
        val obj = mapGet(node, "object")
        val fieldName = toString(mapGet(node, "name"))
        val objReg = compileExpr(fs, obj)
        val dest = allocReg(fs)
        val isNullReg = allocReg(fs)
        emitIsNull(fs, isNullReg, objReg)
        val patches = emitBranch(fs, isNullReg)
        // Then: isNull was true → result = null
        patchJump(fs, toInt(mapGet(patches, "thenPatch")))
        emitConstNull(fs, dest)
        val jumpEnd = emitJump(fs)
        // Else: isNull was false → get field
        patchJump(fs, toInt(mapGet(patches, "elsePatch")))
        emitGetField(fs, dest, objReg, fieldName)
        patchJump(fs, jumpEnd)
        return dest
    }

    // Non-null assertion: expr!!
    // Throws at runtime if expr is null, otherwise passes value through
    if (kind == "nonNullAssert") {
        val operandReg = compileExpr(fs, mapGet(node, "operand"))
        val dest = allocReg(fs)
        emitNullCheck(fs, dest, operandReg)
        return dest
    }

    // Subscript access: obj[index] → listGet(obj, index)
    if (kind == "subscript") {
        val objReg = compileExpr(fs, mapGet(node, "object"))
        val idxReg = compileExpr(fs, mapGet(node, "index"))
        val args = listCreate()
        listAppend(args, objReg)
        listAppend(args, idxReg)
        val dest = allocReg(fs)
        emitCall(fs, dest, "listGet", args)
        return dest
    }

    // Type check: expr is Type → boolean
    if (kind == "typeCheck") {
        val operandReg = compileExpr(fs, mapGet(node, "operand"))
        val typeNode = mapGet(node, "type")
        val typeName = toString(mapGet(typeNode, "name"))
        val dest = allocReg(fs)
        emitTypeCheck(fs, dest, operandReg, typeName)
        return dest
    }

    // Type cast: expr as Type → throws if wrong type
    // Safe cast: expr as? Type → null if wrong type
    if (kind == "typeCast") {
        val operandReg = compileExpr(fs, mapGet(node, "operand"))
        val typeNode = mapGet(node, "type")
        val typeName = toString(mapGet(typeNode, "name"))
        val isSafe = mapGet(node, "safe") == true
        if (isSafe) {
            // as? — TYPE_CHECK then branch: cast or null
            val dest = allocReg(fs)
            val checkReg = allocReg(fs)
            emitTypeCheck(fs, checkReg, operandReg, typeName)
            val patches = emitBranch(fs, checkReg)
            // Then: type matched → cast
            patchJump(fs, toInt(mapGet(patches, "thenPatch")))
            emitTypeCast(fs, dest, operandReg, typeName)
            val jumpEnd = emitJump(fs)
            // Else: type didn't match → null
            patchJump(fs, toInt(mapGet(patches, "elsePatch")))
            emitConstNull(fs, dest)
            patchJump(fs, jumpEnd)
            return dest
        } else {
            // as — direct cast, throws on failure
            val dest = allocReg(fs)
            emitTypeCast(fs, dest, operandReg, typeName)
            return dest
        }
    }

    if (kind == "binary") {
        val op = toString(mapGet(node, "op"))

        // Short-circuit && : if left is false, skip right, result = false
        if (op == "&&") {
            val dest = allocReg(fs)
            val leftReg = compileExpr(fs, mapGet(node, "left"))
            val patches = emitBranch(fs, leftReg)
            // Then: left was true, evaluate right
            patchJump(fs, toInt(mapGet(patches, "thenPatch")))
            val rightReg = compileExpr(fs, mapGet(node, "right"))
            emitStore(fs, dest, rightReg)
            val jumpEnd = emitJump(fs)
            // Else: left was false, result = false
            patchJump(fs, toInt(mapGet(patches, "elsePatch")))
            emitConstFalse(fs, dest)
            patchJump(fs, jumpEnd)
            return dest
        }

        // Short-circuit || : if left is true, skip right, result = true
        if (op == "||") {
            val dest = allocReg(fs)
            val leftReg = compileExpr(fs, mapGet(node, "left"))
            val patches = emitBranch(fs, leftReg)
            // Then: left was true, result = true
            patchJump(fs, toInt(mapGet(patches, "thenPatch")))
            emitConstTrue(fs, dest)
            val jumpEnd = emitJump(fs)
            // Else: left was false, evaluate right
            patchJump(fs, toInt(mapGet(patches, "elsePatch")))
            val rightReg = compileExpr(fs, mapGet(node, "right"))
            emitStore(fs, dest, rightReg)
            patchJump(fs, jumpEnd)
            return dest
        }

        // Elvis operator ?: : if left is null, evaluate right; otherwise use left
        if (op == "?:") {
            val dest = allocReg(fs)
            val leftReg = compileExpr(fs, mapGet(node, "left"))
            val isNullReg = allocReg(fs)
            emitIsNull(fs, isNullReg, leftReg)
            val patches = emitBranch(fs, isNullReg)
            // Then: isNull was true → evaluate right
            patchJump(fs, toInt(mapGet(patches, "thenPatch")))
            val rightReg = compileExpr(fs, mapGet(node, "right"))
            emitStore(fs, dest, rightReg)
            val jumpEnd = emitJump(fs)
            // Else: isNull was false → use left value
            patchJump(fs, toInt(mapGet(patches, "elsePatch")))
            emitStore(fs, dest, leftReg)
            patchJump(fs, jumpEnd)
            return dest
        }

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

        // Simple function call or constructor: funcName(args)
        if (calleeKind == "ident") {
            var funcName: String = toString(mapGet(callee, "name"))

            // Check if this is a class constructor
            val classNames = mapGet(mapGet(fs, "compiler"), "classNames")
            val isClass = mapGet(classNames, funcName)
            if (isClass != null) {
                // Constructor call → NEW_OBJECT
                val argRegs = listCreate()
                var i: Int = 0
                while (i < listSize(callArgs)) {
                    val argNode = listGet(callArgs, i)
                    val argKind = toString(mapGet(argNode, "kind"))
                    if (argKind == "namedArg") {
                        listAppend(argRegs, compileExpr(fs, mapGet(argNode, "value")))
                    } else {
                        listAppend(argRegs, compileExpr(fs, argNode))
                    }
                    i = i + 1
                }
                val dest = allocReg(fs)
                emitNewObject(fs, dest, funcName, argRegs)
                return dest
            }

            // Check if this is a local variable (could hold a lambda reference)
            val localSlot = mapGet(mapGet(fs, "locals"), funcName)
            if (localSlot != null) {
                // Indirect call through variable
                val funcRefReg = allocReg(fs)
                emitLoad(fs, funcRefReg, toInt(localSlot))
                val argRegs = listCreate()
                var i: Int = 0
                while (i < listSize(callArgs)) {
                    val argNode = listGet(callArgs, i)
                    val argKind = toString(mapGet(argNode, "kind"))
                    if (argKind == "namedArg") {
                        listAppend(argRegs, compileExpr(fs, mapGet(argNode, "value")))
                    } else {
                        listAppend(argRegs, compileExpr(fs, argNode))
                    }
                    i = i + 1
                }
                val dest = allocReg(fs)
                emitCallIndirect(fs, dest, funcRefReg, argRegs)
                return dest
            }

            // Resolve local function names to mangled names
            val localFunc = mapGet(mapGet(fs, "localFuncs"), funcName)
            if (localFunc != null) {
                funcName = toString(localFunc)
            }

            // Regular function call — handle named args and defaults
            val sig = mapGet(mapGet(mapGet(fs, "compiler"), "funcSignatures"), funcName)

            // Check if any args are named
            var hasNamed: Bool = false
            var ci: Int = 0
            while (ci < listSize(callArgs)) {
                if (toString(mapGet(listGet(callArgs, ci), "kind")) == "namedArg") {
                    hasNamed = true
                }
                ci = ci + 1
            }

            val argRegs = listCreate()
            if (hasNamed) {
                if (sig != null) {
                    // Build named→register map for named args, track positional args
                    val namedMap = mapCreate()
                    val positional = listCreate()
                    var i: Int = 0
                    while (i < listSize(callArgs)) {
                        val argNode = listGet(callArgs, i)
                        if (toString(mapGet(argNode, "kind")) == "namedArg") {
                            val aName = toString(mapGet(argNode, "name"))
                            mapPut(namedMap, aName, compileExpr(fs, mapGet(argNode, "value")))
                        } else {
                            listAppend(positional, compileExpr(fs, argNode))
                        }
                        i = i + 1
                    }
                    // Reorder: for each param, use named value if available, else positional, else null
                    var pi: Int = 0
                    var posIdx: Int = 0
                    while (pi < listSize(sig)) {
                        val paramName = toString(mapGet(listGet(sig, pi), "name"))
                        val namedVal = mapGet(namedMap, paramName)
                        if (namedVal != null) {
                            listAppend(argRegs, toInt(namedVal))
                        } else {
                            if (posIdx < listSize(positional)) {
                                listAppend(argRegs, toInt(listGet(positional, posIdx)))
                                posIdx = posIdx + 1
                            } else {
                                val nullReg = allocReg(fs)
                                emitConstNull(fs, nullReg)
                                listAppend(argRegs, nullReg)
                            }
                        }
                        pi = pi + 1
                    }
                }
            }
            if (!hasNamed) {
                var i: Int = 0
                while (i < listSize(callArgs)) {
                    val argNode = listGet(callArgs, i)
                    listAppend(argRegs, compileExpr(fs, argNode))
                    i = i + 1
                }
                // Pad with null for default params if fewer args provided
                if (sig != null) {
                    while (listSize(argRegs) < listSize(sig)) {
                        val nullReg = allocReg(fs)
                        emitConstNull(fs, nullReg)
                        listAppend(argRegs, nullReg)
                    }
                }
            }
            val dest = allocReg(fs)
            emitCall(fs, dest, funcName, argRegs)
            return dest
        }

        // Method call: obj.method(args) → VCALL or static CALL for objects
        if (calleeKind == "member") {
            val memberObj = mapGet(callee, "object")
            val methodName = toString(mapGet(callee, "name"))
            // Check if this is an object/companion method call: Name.method()
            val memberObjKind = toString(mapGet(memberObj, "kind"))
            if (memberObjKind == "ident") {
                val memberObjName = toString(mapGet(memberObj, "name"))
                val isObject = mapGet(mapGet(mapGet(fs, "compiler"), "objectNames"), memberObjName)
                val isClass = mapGet(mapGet(mapGet(fs, "compiler"), "classNames"), memberObjName)
                if (isObject != null || isClass != null) {
                    // Static call to ObjectName.method
                    val fullName = stringConcat(memberObjName, stringConcat(".", methodName))
                    val argRegs = listCreate()
                    var i: Int = 0
                    while (i < listSize(callArgs)) {
                        val argNode = listGet(callArgs, i)
                        val argKind = toString(mapGet(argNode, "kind"))
                        if (argKind == "namedArg") {
                            listAppend(argRegs, compileExpr(fs, mapGet(argNode, "value")))
                        } else {
                            listAppend(argRegs, compileExpr(fs, argNode))
                        }
                        i = i + 1
                    }
                    val dest = allocReg(fs)
                    emitCall(fs, dest, fullName, argRegs)
                    return dest
                }
            }
            val objReg = compileExpr(fs, memberObj)

            val argRegs = listCreate()
            var i: Int = 0
            while (i < listSize(callArgs)) {
                val argNode = listGet(callArgs, i)
                val argKind = toString(mapGet(argNode, "kind"))
                if (argKind == "namedArg") {
                    listAppend(argRegs, compileExpr(fs, mapGet(argNode, "value")))
                } else {
                    listAppend(argRegs, compileExpr(fs, argNode))
                }
                i = i + 1
            }

            // Check for extension functions before falling back to VCALL
            val extFuncs = mapGet(mapGet(fs, "compiler"), "extensionFuncs")
            val extKeys = mapKeys(extFuncs)
            var extFound: String = ""
            var ei: Int = 0
            while (ei < listSize(extKeys)) {
                val extName = toString(listGet(extKeys, ei))
                if (endsWith(extName, stringConcat(".", methodName))) {
                    extFound = extName
                }
                ei = ei + 1
            }
            if (stringLength(extFound) > 0) {
                // Extension function call: prepend receiver as first arg
                val extArgs = listCreate()
                listAppend(extArgs, objReg)
                var ea: Int = 0
                while (ea < listSize(argRegs)) {
                    listAppend(extArgs, toInt(listGet(argRegs, ea)))
                    ea = ea + 1
                }
                val dest = allocReg(fs)
                emitCall(fs, dest, extFound, extArgs)
                return dest
            }

            val dest = allocReg(fs)
            emitVcall(fs, dest, objReg, methodName, argRegs)
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

    if (kind == "lambda") {
        return compileLambda(fs, node)
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
// Lambda compilation
// ---------------------------------------------------------------------------

// Collect free variable names from an expression AST node
fun collectFreeVarsExpr(node: Map, names: Map): Unit {
    if (node == null) { return }
    val kind = toString(mapGet(node, "kind"))
    if (kind == "ident") {
        mapPut(names, toString(mapGet(node, "name")), 1)
    } else if (kind == "binary") {
        collectFreeVarsExpr(mapGet(node, "left"), names)
        collectFreeVarsExpr(mapGet(node, "right"), names)
    } else if (kind == "unary") {
        collectFreeVarsExpr(mapGet(node, "operand"), names)
    } else if (kind == "call") {
        collectFreeVarsExpr(mapGet(node, "callee"), names)
        val args = mapGet(node, "args")
        if (args != null) {
            var i: Int = 0
            while (i < listSize(args)) {
                val arg = listGet(args, i)
                collectFreeVarsExpr(mapGet(arg, "value"), names)
                i = i + 1
            }
        }
    } else if (kind == "member") {
        collectFreeVarsExpr(mapGet(node, "object"), names)
    } else if (kind == "interpolatedString") {
        val parts = mapGet(node, "parts")
        if (parts != null) {
            var i: Int = 0
            while (i < listSize(parts)) {
                val part = listGet(parts, i)
                if (toString(mapGet(part, "kind")) == "expr") {
                    collectFreeVarsExpr(mapGet(part, "expr"), names)
                }
                i = i + 1
            }
        }
    } else if (kind == "elvis") {
        collectFreeVarsExpr(mapGet(node, "left"), names)
        collectFreeVarsExpr(mapGet(node, "right"), names)
    } else if (kind == "nonNullAssert") {
        collectFreeVarsExpr(mapGet(node, "expr"), names)
    } else if (kind == "paren") {
        collectFreeVarsExpr(mapGet(node, "expr"), names)
    }
}

// Collect free variable names from a statement AST node
fun collectFreeVarsStmt(node: Map, names: Map): Unit {
    if (node == null) { return }
    val kind = toString(mapGet(node, "kind"))
    if (kind == "exprStmt") {
        collectFreeVarsExpr(mapGet(node, "expr"), names)
    } else if (kind == "return") {
        collectFreeVarsExpr(mapGet(node, "value"), names)
    } else if (kind == "valDecl") {
        collectFreeVarsExpr(mapGet(node, "init"), names)
    } else if (kind == "varDecl") {
        collectFreeVarsExpr(mapGet(node, "init"), names)
    } else if (kind == "assign") {
        collectFreeVarsExpr(mapGet(node, "value"), names)
        val target = mapGet(node, "target")
        if (target != null) {
            collectFreeVarsExpr(target, names)
        }
    } else if (kind == "while") {
        collectFreeVarsExpr(mapGet(node, "condition"), names)
        val body = mapGet(node, "body")
        if (body != null) {
            val stmts = mapGet(body, "stmts")
            if (stmts != null) {
                var i: Int = 0
                while (i < listSize(stmts)) {
                    collectFreeVarsStmt(listGet(stmts, i), names)
                    i = i + 1
                }
            }
        }
    } else if (kind == "for") {
        collectFreeVarsExpr(mapGet(node, "iterable"), names)
        val body = mapGet(node, "body")
        if (body != null) {
            val stmts = mapGet(body, "stmts")
            if (stmts != null) {
                var i: Int = 0
                while (i < listSize(stmts)) {
                    collectFreeVarsStmt(listGet(stmts, i), names)
                    i = i + 1
                }
            }
        }
    } else if (kind == "if") {
        collectFreeVarsExpr(mapGet(node, "condition"), names)
        val thenBody = mapGet(node, "then")
        if (thenBody != null) {
            val stmts = mapGet(thenBody, "stmts")
            if (stmts != null) {
                var i: Int = 0
                while (i < listSize(stmts)) {
                    collectFreeVarsStmt(listGet(stmts, i), names)
                    i = i + 1
                }
            }
        }
        val elseBody = mapGet(node, "else")
        if (elseBody != null) {
            val eStmts = mapGet(elseBody, "stmts")
            if (eStmts != null) {
                var i: Int = 0
                while (i < listSize(eStmts)) {
                    collectFreeVarsStmt(listGet(eStmts, i), names)
                    i = i + 1
                }
            }
        }
    } else {
        // Unknown statement kind — might be a bare expression (e.g., binary, call, identifier)
        collectFreeVarsExpr(node, names)
    }
}

fun compileLambda(fs: Map, node: Map): Int {
    val compiler = mapGet(fs, "compiler")

    // Generate unique lambda name
    val counter = toInt(mapGet(compiler, "lambdaCounter"))
    mapPut(compiler, "lambdaCounter", counter + 1)
    val lambdaName = stringConcat("__lambda_", toString(counter))

    // Build params list for the lambda function
    val params = mapGet(node, "params")
    val lambdaParams = listCreate()
    val paramNames = mapCreate()
    if (params != null) {
        var i: Int = 0
        while (i < listSize(params)) {
            val p = listGet(params, i)
            listAppend(lambdaParams, p)
            mapPut(paramNames, toString(mapGet(p, "name")), 1)
            i = i + 1
        }
    }

    // Collect free variables from the lambda body
    val freeNames = mapCreate()
    val body = mapGet(node, "body")
    val stmts = mapGet(body, "stmts")
    if (stmts != null) {
        var i: Int = 0
        while (i < listSize(stmts)) {
            collectFreeVarsStmt(listGet(stmts, i), freeNames)
            i = i + 1
        }
    }

    // Determine captures: names in freeNames that are in outer locals but not in lambda params
    val outerLocals = mapGet(fs, "locals")
    val captures = listCreate()
    val captureKeys = mapKeys(freeNames)
    var ci: Int = 0
    while (ci < listSize(captureKeys)) {
        val name = toString(listGet(captureKeys, ci))
        if (mapGet(paramNames, name) == null) {
            if (mapGet(outerLocals, name) != null) {
                listAppend(captures, name)
            }
        }
        ci = ci + 1
    }

    // Add capture parameters before user params
    val allParams = listCreate()
    var cj: Int = 0
    while (cj < listSize(captures)) {
        val capParam = mapCreate()
        mapPut(capParam, "name", toString(listGet(captures, cj)))
        listAppend(allParams, capParam)
        cj = cj + 1
    }
    var pk: Int = 0
    while (pk < listSize(lambdaParams)) {
        listAppend(allParams, listGet(lambdaParams, pk))
        pk = pk + 1
    }

    // Transform body: if last statement is an expression, wrap it in return
    if (stmts != null) {
        val stmtCount = listSize(stmts)
        if (stmtCount > 0) {
            val lastStmt = listGet(stmts, stmtCount - 1)
            val lastKind = toString(mapGet(lastStmt, "kind"))
            if (lastKind != "return" && lastKind != "break" && lastKind != "continue" && lastKind != "valDecl" && lastKind != "varDecl" && lastKind != "assign" && lastKind != "while" && lastKind != "for" && lastKind != "if") {
                val retNode = mapCreate()
                mapPut(retNode, "kind", "return")
                mapPut(retNode, "value", lastStmt)
                listSet(stmts, stmtCount - 1, retNode)
            }
        }
    }

    // Create a function declaration for the lambda
    val decl = mapCreate()
    mapPut(decl, "kind", "funDecl")
    mapPut(decl, "name", lambdaName)
    mapPut(decl, "params", allParams)
    mapPut(decl, "body", body)

    // Compile the lambda as a top-level function
    compileFunction(compiler, decl)

    val dest = allocReg(fs)
    if (listSize(captures) == 0) {
        // No captures: return function name string
        emitConstString(fs, dest, lambdaName)
    } else {
        // Build closure list: [funcName, cap0, cap1, ...]
        emitCall(fs, dest, "listCreate", listCreate())
        val fnReg = allocReg(fs)
        emitConstString(fs, fnReg, lambdaName)
        val appendArgs1 = listCreate()
        listAppend(appendArgs1, dest)
        listAppend(appendArgs1, fnReg)
        emitCall(fs, allocReg(fs), "listAppend", appendArgs1)
        var ck: Int = 0
        while (ck < listSize(captures)) {
            val capName = toString(listGet(captures, ck))
            val capSlot = toInt(mapGet(outerLocals, capName))
            val appendArgs = listCreate()
            listAppend(appendArgs, dest)
            listAppend(appendArgs, capSlot)
            emitCall(fs, allocReg(fs), "listAppend", appendArgs)
            ck = ck + 1
        }
    }
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

    val dest = allocReg(fs)
    emitConstNull(fs, dest)

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
                val valReg = compileExpr(fs, body)
                emitStore(fs, dest, valReg)
            }
        } else {
            // Pattern matching branch — OR-combine all patterns
            val patterns = mapGet(branch, "patterns")
            var condReg: Int = allocReg(fs)
            emitConstFalse(fs, condReg)
            var pi: Int = 0
            while (pi < listSize(patterns)) {
                val pattern = listGet(patterns, pi)
                val patKind = toString(mapGet(pattern, "kind"))
                val singleCond = allocReg(fs)
                if (subject == null) {
                    // No subject — pattern is a boolean condition
                    val exprReg = compileExpr(fs, pattern)
                    emitStore(fs, singleCond, exprReg)
                } else if (patKind == "isPattern") {
                    // Type check pattern: is Type
                    val typeNode = mapGet(pattern, "type")
                    val typeName = toString(mapGet(typeNode, "name"))
                    emitTypeCheck(fs, singleCond, subjectReg, typeName)
                } else {
                    // Value equality pattern — check if it's an enum member
                    var isEnumPat: Bool = false
                    if (patKind == "member") {
                        val patObj = mapGet(pattern, "object")
                        if (patObj != null) {
                            if (isMap(patObj)) {
                                if (toString(mapGet(patObj, "kind")) == "ident") {
                                    val patObjName = toString(mapGet(patObj, "name"))
                                    val patEnumEntries = mapGet(mapGet(mapGet(fs, "compiler"), "enumNames"), patObjName)
                                    if (patEnumEntries != null) {
                                        isEnumPat = true
                                    }
                                }
                            }
                        }
                    }
                    if (isEnumPat) {
                        // Compare __variant fields
                        val subjectVariant = allocReg(fs)
                        emitGetField(fs, subjectVariant, subjectReg, "__variant")
                        val patternReg = compileExpr(fs, pattern)
                        val patternVariant = allocReg(fs)
                        emitGetField(fs, patternVariant, patternReg, "__variant")
                        emitBinaryOp(fs, "==", singleCond, subjectVariant, patternVariant)
                    } else {
                        val patternReg = compileExpr(fs, pattern)
                        emitBinaryOp(fs, "==", singleCond, subjectReg, patternReg)
                    }
                }
                emitBinaryOp(fs, "||", condReg, condReg, singleCond)
                pi = pi + 1
            }
            val patches = emitBranch(fs, condReg)
            patchJump(fs, toInt(mapGet(patches, "thenPatch")))

            val body = mapGet(branch, "body")
            val bodyKind = toString(mapGet(body, "kind"))
            if (bodyKind == "block") {
                compileBlock(fs, body)
            } else {
                val valReg = compileExpr(fs, body)
                emitStore(fs, dest, valReg)
            }
            listAppend(endPatches, emitJump(fs))

            patchJump(fs, toInt(mapGet(patches, "elsePatch")))
        }
        i = i + 1
    }

    // Exhaustiveness check for sealed class when expressions
    val sealedNames = mapGet(mapGet(fs, "compiler"), "sealedNames")
    var hasElse: Bool = false
    val coveredTypes = listCreate()
    var ci: Int = 0
    while (ci < listSize(branches)) {
        val br = listGet(branches, ci)
        if (mapGet(br, "isElse") == true) {
            hasElse = true
        } else {
            val pats = mapGet(br, "patterns")
            if (listSize(pats) > 0) {
                val pat = listGet(pats, 0)
                if (toString(mapGet(pat, "kind")) == "isPattern") {
                    val tNode = mapGet(pat, "type")
                    listAppend(coveredTypes, toString(mapGet(tNode, "name")))
                }
            }
        }
        ci = ci + 1
    }
    if (!hasElse) {
        if (listSize(coveredTypes) > 0) {
            // Check each sealed class to see if all subclasses are covered
            val sealedKeys = mapKeys(sealedNames)
            var sk: Int = 0
            while (sk < listSize(sealedKeys)) {
                val sealedName = toString(listGet(sealedKeys, sk))
                val subs = mapGet(sealedNames, sealedName)
                if (listSize(subs) > 0) {
                    var allCovered: Bool = true
                    var si: Int = 0
                    while (si < listSize(subs)) {
                        val subName = toString(listGet(subs, si))
                        if (!listContains(coveredTypes, subName)) {
                            allCovered = false
                        }
                        si = si + 1
                    }
                    if (!allCovered) {
                        // Find missing subclasses
                        var mi: Int = 0
                        while (mi < listSize(subs)) {
                            val subName = toString(listGet(subs, mi))
                            if (!listContains(coveredTypes, subName)) {
                                val warning = stringConcat("warning: 'when' on sealed class '", stringConcat(sealedName, stringConcat("' missing branch for '", stringConcat(subName, "'"))))
                                println(warning)
                            }
                            mi = mi + 1
                        }
                    }
                }
                sk = sk + 1
            }
        }
    }

    // Patch all end jumps
    var j: Int = 0
    while (j < listSize(endPatches)) {
        patchJump(fs, toInt(listGet(endPatches, j)))
        j = j + 1
    }

    return dest
}

// ---------------------------------------------------------------------------
// Statement compilation
// ---------------------------------------------------------------------------

fun compileStmt(fs: Map, node: Map): Unit {
    if (mapGet(node, "line") != null) { trackLine(fs, node) }
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

    // Destructuring: val (a, b, c) = expr
    if (kind == "destructure") {
        val names = mapGet(node, "names")
        val initReg = compileExpr(fs, mapGet(node, "init"))
        // Try to get type name to determine if this is a class or list
        // For class objects: access fields by position (using class field names)
        // For lists: access by index
        // Strategy: try GET_FIELD with component1/component2 names first,
        // then fall back to list indexing
        var di: Int = 0
        while (di < listSize(names)) {
            val varName = toString(listGet(names, di))
            val slot = allocReg(fs)
            mapPut(mapGet(fs, "locals"), varName, slot)
            // Use listGet for destructuring (works for lists and positional access)
            val args = listCreate()
            listAppend(args, initReg)
            val idxReg = allocReg(fs)
            emitConstInt(fs, idxReg, di)
            listAppend(args, idxReg)
            val elemReg = allocReg(fs)
            emitCall(fs, elemReg, "listGet", args)
            emitStore(fs, slot, elemReg)
            di = di + 1
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
            } else {
                // Check if in method and name is a class field
                val methodClass = mapGet(fs, "className")
                if (methodClass != null) {
                    val classFields = mapGet(fs, "classFields")
                    if (listContains(classFields, name)) {
                        val thisSlot = toInt(mapGet(mapGet(fs, "locals"), "this"))
                        val thisReg = allocReg(fs)
                        emitLoad(fs, thisReg, thisSlot)
                        val valueReg = compileExpr(fs, mapGet(node, "value"))
                        emitSetField(fs, thisReg, name, valueReg)
                    }
                }
            }
        }
        if (targetKind == "member") {
            val objReg = compileExpr(fs, mapGet(target, "object"))
            val fieldName = toString(mapGet(target, "name"))
            val valueReg = compileExpr(fs, mapGet(node, "value"))
            emitSetField(fs, objReg, fieldName, valueReg)
        }
        if (targetKind == "subscript") {
            // a[i] = value → listSet(a, i, value)
            val objReg = compileExpr(fs, mapGet(target, "object"))
            val idxReg = compileExpr(fs, mapGet(target, "index"))
            val valueReg = compileExpr(fs, mapGet(node, "value"))
            val args = listCreate()
            listAppend(args, objReg)
            listAppend(args, idxReg)
            listAppend(args, valueReg)
            val dest = allocReg(fs)
            emitCall(fs, dest, "listSet", args)
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
        val varName = toString(mapGet(node, "variable"))
        val iterable = mapGet(node, "iterable")
        val iterKind = toString(mapGet(iterable, "kind"))

        // Check for range expressions: 0..n or 0..<n
        var isRange: Bool = false
        var rangeOp: String = ""
        if (iterKind == "binary") {
            rangeOp = toString(mapGet(iterable, "op"))
            if (rangeOp == ".." || rangeOp == "..<") {
                isRange = true
            }
        }

        if (isRange) {
            // Range-based for loop: for (i in start..end) or for (i in start..<end)
            val startReg = compileExpr(fs, mapGet(iterable, "left"))
            val endReg = compileExpr(fs, mapGet(iterable, "right"))

            // If inclusive (..), add 1 to end for the comparison
            var limitReg: Int = endReg
            if (rangeOp == "..") {
                val oneReg = allocReg(fs)
                emitConstInt(fs, oneReg, 1)
                limitReg = allocReg(fs)
                emitBinaryOp(fs, "+", limitReg, endReg, oneReg)
            }

            // Counter slot
            val counterSlot = allocReg(fs)
            emitStore(fs, counterSlot, startReg)

            val loopStart = currentOffset(fs)
            val breakLabel = newLabel(fs)
            val continueLabel = newLabel(fs)

            val loopCtx = mapCreate()
            mapPut(loopCtx, "breakLabel", breakLabel)
            mapPut(loopCtx, "continueLabel", continueLabel)
            listAppend(mapGet(fs, "loopStack"), loopCtx)

            // Condition: counter < limit
            markLabel(fs, continueLabel)
            val curReg = allocReg(fs)
            emitLoad(fs, curReg, counterSlot)
            val condReg = allocReg(fs)
            emitBinaryOp(fs, "<", condReg, curReg, limitReg)
            val patches = emitBranch(fs, condReg)
            patchJump(fs, toInt(mapGet(patches, "thenPatch")))

            // Bind loop variable
            val varSlot = allocReg(fs)
            val varLoadReg = allocReg(fs)
            emitLoad(fs, varLoadReg, counterSlot)
            emitStore(fs, varSlot, varLoadReg)
            mapPut(mapGet(fs, "locals"), varName, varSlot)

            // Body
            compileBlock(fs, mapGet(node, "body"))

            // Increment counter
            val curIdx2 = allocReg(fs)
            emitLoad(fs, curIdx2, counterSlot)
            val oneReg2 = allocReg(fs)
            emitConstInt(fs, oneReg2, 1)
            val newIdx = allocReg(fs)
            emitBinaryOp(fs, "+", newIdx, curIdx2, oneReg2)
            emitStore(fs, counterSlot, newIdx)

            // Loop back
            emitByte(fs, OP_JUMP())
            emitU32(fs, loopStart)

            // Exit
            patchJump(fs, toInt(mapGet(patches, "elsePatch")))
            markLabel(fs, breakLabel)

            listRemoveAt(mapGet(fs, "loopStack"), listSize(mapGet(fs, "loopStack")) - 1)
            return
        }

        // List-based for loop
        val iterReg = compileExpr(fs, iterable)

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

    if (kind == "forDestructure") {
        // for ((k, v) in map) { body }
        // Strategy: get keys, iterate by index, get value for each key
        val vars = mapGet(node, "variables")
        val iterable = mapGet(node, "iterable")
        val iterReg = compileExpr(fs, iterable)

        // Get keys list
        val keysArgs = listCreate()
        listAppend(keysArgs, iterReg)
        val keysReg = allocReg(fs)
        emitCall(fs, keysReg, "mapKeys", keysArgs)

        // Size of keys
        val sizeArgs = listCreate()
        listAppend(sizeArgs, keysReg)
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

        // Get key at index
        val getKeyArgs = listCreate()
        listAppend(getKeyArgs, keysReg)
        val idxReg2 = allocReg(fs)
        emitLoad(fs, idxReg2, indexSlot)
        listAppend(getKeyArgs, idxReg2)
        val keyReg = allocReg(fs)
        emitCall(fs, keyReg, "listGet", getKeyArgs)

        // Bind first variable (key)
        val keySlot = allocReg(fs)
        emitStore(fs, keySlot, keyReg)
        mapPut(mapGet(fs, "locals"), toString(listGet(vars, 0)), keySlot)

        // If two variables, get value from map
        if (listSize(vars) > 1) {
            val getValArgs = listCreate()
            listAppend(getValArgs, iterReg)
            listAppend(getValArgs, keyReg)
            val valReg = allocReg(fs)
            emitCall(fs, valReg, "mapGet", getValArgs)
            val valSlot = allocReg(fs)
            emitStore(fs, valSlot, valReg)
            mapPut(mapGet(fs, "locals"), toString(listGet(vars, 1)), valSlot)
        }

        // Body
        compileBlock(fs, mapGet(node, "body"))

        // Increment index
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

        val fdStack = mapGet(fs, "loopStack")
        listRemoveAt(fdStack, listSize(fdStack) - 1)
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
        // Finally after try (normal path)
        val finallyBody = mapGet(node, "finallyBody")
        if (finallyBody != null) {
            compileBlock(fs, finallyBody)
        }
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
        // Finally after catch
        if (finallyBody != null) {
            compileBlock(fs, finallyBody)
        }

        patchJump(fs, jumpToEnd)
        return
    }

    if (kind == "when") {
        compileWhenExpr(fs, node)
        return
    }

    if (kind == "funDecl") {
        // Nested/local function — compile with mangled name
        val localName = toString(mapGet(node, "name"))
        val enclosing = toString(mapGet(fs, "name"))
        val mangledName = stringConcat(enclosing, stringConcat("$", localName))

        // Create a modified decl with the mangled name
        val localDecl = mapCreate()
        mapPut(localDecl, "kind", "funDecl")
        mapPut(localDecl, "name", mangledName)
        mapPut(localDecl, "params", mapGet(node, "params"))
        mapPut(localDecl, "body", mapGet(node, "body"))
        mapPut(localDecl, "returnType", mapGet(node, "returnType"))

        // Compile it as a top-level function
        val compiler = mapGet(fs, "compiler")
        compileFunction(compiler, localDecl)

        // Register the mangled name so calls to localName resolve to mangledName
        mapPut(mapGet(fs, "localFuncs"), localName, mangledName)
        // Also register in funcSignatures for the mangled name
        val fparams = mapGet(node, "params")
        if (fparams != null) {
            mapPut(mapGet(compiler, "funcSignatures"), mangledName, fparams)
        }
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

    // Extension function: prepend receiver as implicit "this" parameter
    val receiverType = mapGet(decl, "receiverType")
    val effectiveParams = listCreate()
    if (receiverType != null) {
        val thisParam = mapCreate()
        mapPut(thisParam, "name", "this")
        mapPut(thisParam, "kind", "param")
        listAppend(effectiveParams, thisParam)
    }
    var epi: Int = 0
    while (epi < listSize(params)) {
        listAppend(effectiveParams, listGet(params, epi))
        epi = epi + 1
    }

    val nameIdx = addFuncName(compiler, name)
    val fs = makeFuncState(compiler, name, effectiveParams)

    // Set class context if this is a method
    val methodClassName = mapGet(decl, "_className")
    if (methodClassName != null) {
        mapPut(fs, "className", toString(methodClassName))
        mapPut(fs, "classFields", mapGet(decl, "_classFields"))
        mapPut(fs, "classMethods", mapGet(decl, "_classMethods"))
    }

    // Load params into alloc slots
    var i: Int = 0
    while (i < listSize(effectiveParams)) {
        val paramReg = allocReg(fs)
        emitLoadParam(fs, paramReg, i)
        val pname = toString(mapGet(listGet(effectiveParams, i), "name"))
        val slot = allocReg(fs)
        emitStore(fs, slot, paramReg)
        mapPut(mapGet(fs, "locals"), pname, slot)

        // Handle default parameter values
        val paramNode = listGet(effectiveParams, i)
        val defaultExpr = mapGet(paramNode, "default")
        if (defaultExpr != null) {
            // If param is null (omitted by caller), use default value
            val checkReg = allocReg(fs)
            emitLoad(fs, checkReg, slot)
            val isNullReg = allocReg(fs)
            emitIsNull(fs, isNullReg, checkReg)
            val patches2 = emitBranch(fs, isNullReg)
            // Then: param is null → assign default
            patchJump(fs, toInt(mapGet(patches2, "thenPatch")))
            val defaultReg = compileExpr(fs, defaultExpr)
            emitStore(fs, slot, defaultReg)
            // Else: param was provided → skip
            patchJump(fs, toInt(mapGet(patches2, "elsePatch")))
        }

        i = i + 1
    }

    // Store function signature info for call sites
    mapPut(mapGet(compiler, "funcSignatures"), name, params)

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
    mapPut(funcRec, "paramCount", listSize(effectiveParams))
    mapPut(funcRec, "regCount", toInt(mapGet(fs, "regCount")))
    mapPut(funcRec, "bytecode", bc)
    mapPut(funcRec, "params", effectiveParams)
    mapPut(funcRec, "lineTable", mapGet(fs, "lineTable"))

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
// Class compilation
// ---------------------------------------------------------------------------

fun compileClassDecl(compiler: Map, decl: Map): Unit {
    val className = toString(mapGet(decl, "name"))

    // Collect fields from constructor params
    val fields = listCreate()
    val ctorParams = mapGet(decl, "ctorParams")
    if (ctorParams != null) {
        var i: Int = 0
        while (i < listSize(ctorParams)) {
            val param = listGet(ctorParams, i)
            val fieldRec = mapCreate()
            mapPut(fieldRec, "name", toString(mapGet(param, "name")))
            val ptype = mapGet(param, "type")
            if (ptype != null) {
                mapPut(fieldRec, "typeName", toString(mapGet(ptype, "name")))
            } else {
                mapPut(fieldRec, "typeName", "Unit")
            }
            listAppend(fields, fieldRec)
            i = i + 1
        }
    }

    // Collect fields from body val/var declarations
    val body = mapGet(decl, "body")
    if (body != null) {
        val members = mapGet(body, "members")
        if (members != null) {
            var i: Int = 0
            while (i < listSize(members)) {
                val member = listGet(members, i)
                val mkind = toString(mapGet(member, "kind"))
                if (mkind == "valDecl" || mkind == "varDecl") {
                    val fieldRec = mapCreate()
                    mapPut(fieldRec, "name", toString(mapGet(member, "name")))
                    val mtype = mapGet(member, "type")
                    if (mtype != null) {
                        mapPut(fieldRec, "typeName", toString(mapGet(mtype, "name")))
                    } else {
                        mapPut(fieldRec, "typeName", "Unit")
                    }
                    listAppend(fields, fieldRec)
                }
                i = i + 1
            }
        }
    }

    // Build field name list for method compilation
    val fieldNames = listCreate()
    var fi: Int = 0
    while (fi < listSize(fields)) {
        listAppend(fieldNames, toString(mapGet(listGet(fields, fi), "name")))
        fi = fi + 1
    }

    // Collect method names first (needed for self-calls within methods)
    val methods = listCreate()
    if (body != null) {
        val members = mapGet(body, "members")
        if (members != null) {
            var i: Int = 0
            while (i < listSize(members)) {
                val member = listGet(members, i)
                val mkind = toString(mapGet(member, "kind"))
                if (mkind == "funDecl") {
                    listAppend(methods, toString(mapGet(member, "name")))
                }
                i = i + 1
            }
        }
    }

    // Compile methods
    if (body != null) {
        val members = mapGet(body, "members")
        if (members != null) {
            var i: Int = 0
            while (i < listSize(members)) {
                val member = listGet(members, i)
                val mkind = toString(mapGet(member, "kind"))
                if (mkind == "funDecl") {
                    val methodName = toString(mapGet(member, "name"))

                    // Build method decl with implicit 'this' parameter
                    val methodParams = listCreate()
                    val thisParam = mapCreate()
                    mapPut(thisParam, "kind", "param")
                    mapPut(thisParam, "name", "this")
                    listAppend(methodParams, thisParam)

                    val origParams = mapGet(member, "params")
                    if (origParams != null) {
                        var pi: Int = 0
                        while (pi < listSize(origParams)) {
                            listAppend(methodParams, listGet(origParams, pi))
                            pi = pi + 1
                        }
                    }

                    val methodDecl = mapCreate()
                    mapPut(methodDecl, "kind", "funDecl")
                    mapPut(methodDecl, "name", stringConcat(className, stringConcat(".", methodName)))
                    mapPut(methodDecl, "params", methodParams)
                    mapPut(methodDecl, "body", mapGet(member, "body"))
                    mapPut(methodDecl, "returnType", mapGet(member, "returnType"))
                    mapPut(methodDecl, "_className", className)
                    mapPut(methodDecl, "_classFields", fieldNames)
                    mapPut(methodDecl, "_classMethods", methods)

                    compileFunction(compiler, methodDecl)
                }
                if (mkind == "companionObject") {
                    // Compile companion methods as ClassName.method (static, no 'this')
                    val compBody = mapGet(member, "body")
                    if (compBody != null) {
                        val compMembers = mapGet(compBody, "members")
                        if (compMembers != null) {
                            var ci: Int = 0
                            while (ci < listSize(compMembers)) {
                                val compMember = listGet(compMembers, ci)
                                if (toString(mapGet(compMember, "kind")) == "funDecl") {
                                    val compMethodName = toString(mapGet(compMember, "name"))
                                    val compDecl = mapCreate()
                                    mapPut(compDecl, "kind", "funDecl")
                                    mapPut(compDecl, "name", stringConcat(className, stringConcat(".", compMethodName)))
                                    mapPut(compDecl, "params", mapGet(compMember, "params"))
                                    mapPut(compDecl, "body", mapGet(compMember, "body"))
                                    mapPut(compDecl, "returnType", mapGet(compMember, "returnType"))
                                    compileFunction(compiler, compDecl)
                                }
                                ci = ci + 1
                            }
                        }
                    }
                }
                i = i + 1
            }
        }
    }

    // Data class: auto-generate toString method
    val isData = mapGet(decl, "isData") == true
    if (isData) {
        // Check if user already defined toString
        if (!listContains(methods, "toString")) {
            listAppend(methods, "toString")
            // Build synthetic toString body:
            // return "ClassName(field1=<val1>, field2=<val2>)"
            val toStrStmts = listCreate()

            // var result = "ClassName("
            val initNode = makeNode("valDecl")
            mapPut(initNode, "name", "__result")
            val initStr = makeNode("stringLit")
            mapPut(initStr, "value", stringConcat(className, "("))
            mapPut(initNode, "init", initStr)
            listAppend(toStrStmts, initNode)

            // For each field: result = stringConcat(result, "fieldName=") + toString(this.field) + ", "
            var dfi: Int = 0
            while (dfi < listSize(fieldNames)) {
                val fname = toString(listGet(fieldNames, dfi))
                // Build: __result = stringConcat(__result, "fname=")
                val concatAssign1 = makeNode("assign")
                val target1 = makeNode("ident")
                mapPut(target1, "name", "__result")
                mapPut(concatAssign1, "target", target1)
                val concat1 = makeNode("call")
                val concat1Callee = makeNode("ident")
                mapPut(concat1Callee, "name", "stringConcat")
                mapPut(concat1, "callee", concat1Callee)
                val concat1Args = listCreate()
                val arg1a = makeNode("ident")
                mapPut(arg1a, "name", "__result")
                listAppend(concat1Args, arg1a)
                val prefix = stringConcat(fname, "=")
                if (dfi > 0) {
                    val arg1b = makeNode("stringLit")
                    mapPut(arg1b, "value", stringConcat(", ", prefix))
                    listAppend(concat1Args, arg1b)
                } else {
                    val arg1b = makeNode("stringLit")
                    mapPut(arg1b, "value", prefix)
                    listAppend(concat1Args, arg1b)
                }
                mapPut(concat1, "args", concat1Args)
                mapPut(concatAssign1, "value", concat1)
                listAppend(toStrStmts, concatAssign1)

                // Build: __result = stringConcat(__result, toString(this.fname))
                val concatAssign2 = makeNode("assign")
                val target2 = makeNode("ident")
                mapPut(target2, "name", "__result")
                mapPut(concatAssign2, "target", target2)
                val concat2 = makeNode("call")
                val concat2Callee = makeNode("ident")
                mapPut(concat2Callee, "name", "stringConcat")
                mapPut(concat2, "callee", concat2Callee)
                val concat2Args = listCreate()
                val arg2a = makeNode("ident")
                mapPut(arg2a, "name", "__result")
                listAppend(concat2Args, arg2a)
                // toString(this.fname)
                val toStrCall = makeNode("call")
                val toStrCallee = makeNode("ident")
                mapPut(toStrCallee, "name", "toString")
                mapPut(toStrCall, "callee", toStrCallee)
                val toStrArgs = listCreate()
                val fieldAccess = makeNode("ident")
                mapPut(fieldAccess, "name", fname)
                listAppend(toStrArgs, fieldAccess)
                mapPut(toStrCall, "args", toStrArgs)
                listAppend(concat2Args, toStrCall)
                mapPut(concat2, "args", concat2Args)
                mapPut(concatAssign2, "value", concat2)
                listAppend(toStrStmts, concatAssign2)

                dfi = dfi + 1
            }

            // Build: __result = stringConcat(__result, ")")
            val concatClose = makeNode("assign")
            val targetClose = makeNode("ident")
            mapPut(targetClose, "name", "__result")
            mapPut(concatClose, "target", targetClose)
            val concatCloseCall = makeNode("call")
            val concatCloseCallee = makeNode("ident")
            mapPut(concatCloseCallee, "name", "stringConcat")
            mapPut(concatCloseCall, "callee", concatCloseCallee)
            val concatCloseArgs = listCreate()
            val argCloseA = makeNode("ident")
            mapPut(argCloseA, "name", "__result")
            listAppend(concatCloseArgs, argCloseA)
            val argCloseB = makeNode("stringLit")
            mapPut(argCloseB, "value", ")")
            listAppend(concatCloseArgs, argCloseB)
            mapPut(concatCloseCall, "args", concatCloseArgs)
            mapPut(concatClose, "value", concatCloseCall)
            listAppend(toStrStmts, concatClose)

            // return __result
            val retNode = makeNode("return")
            val retIdent = makeNode("ident")
            mapPut(retIdent, "name", "__result")
            mapPut(retNode, "value", retIdent)
            listAppend(toStrStmts, retNode)

            val toStrBody = makeNode("block")
            mapPut(toStrBody, "stmts", toStrStmts)

            val methodDecl = mapCreate()
            mapPut(methodDecl, "kind", "funDecl")
            mapPut(methodDecl, "name", stringConcat(className, ".toString"))
            val toStrParams = listCreate()
            val thisParam2 = mapCreate()
            mapPut(thisParam2, "kind", "param")
            mapPut(thisParam2, "name", "this")
            listAppend(toStrParams, thisParam2)
            mapPut(methodDecl, "params", toStrParams)
            mapPut(methodDecl, "body", toStrBody)
            mapPut(methodDecl, "_className", className)
            mapPut(methodDecl, "_classFields", fieldNames)
            mapPut(methodDecl, "_classMethods", methods)
            compileFunction(compiler, methodDecl)
        }

        // Auto-generate equals method
        if (!listContains(methods, "equals")) {
            listAppend(methods, "equals")
            // Build: fun equals(other): Bool { return field1==other.field1 && ... }
            val eqStmts = listCreate()

            // Build comparison expression: this.f1 == other.f1 && this.f2 == other.f2 ...
            var eqExpr: Map = makeNode("boolLit")
            mapPut(eqExpr, "value", true)

            var efi: Int = 0
            while (efi < listSize(fieldNames)) {
                val fname = toString(listGet(fieldNames, efi))
                val leftField = makeNode("ident")
                mapPut(leftField, "name", fname)
                val rightField = makeNode("member")
                val otherIdent = makeNode("ident")
                mapPut(otherIdent, "name", "other")
                mapPut(rightField, "object", otherIdent)
                mapPut(rightField, "name", fname)
                val cmp = makeNode("binary")
                mapPut(cmp, "op", "==")
                mapPut(cmp, "left", leftField)
                mapPut(cmp, "right", rightField)

                if (efi == 0) {
                    eqExpr = cmp
                } else {
                    val andNode = makeNode("binary")
                    mapPut(andNode, "op", "&&")
                    mapPut(andNode, "left", eqExpr)
                    mapPut(andNode, "right", cmp)
                    eqExpr = andNode
                }
                efi = efi + 1
            }

            val retNode2 = makeNode("return")
            mapPut(retNode2, "value", eqExpr)
            listAppend(eqStmts, retNode2)

            val eqBody = makeNode("block")
            mapPut(eqBody, "stmts", eqStmts)

            val eqDecl = mapCreate()
            mapPut(eqDecl, "kind", "funDecl")
            mapPut(eqDecl, "name", stringConcat(className, ".equals"))
            val eqParams = listCreate()
            val thisParam3 = mapCreate()
            mapPut(thisParam3, "kind", "param")
            mapPut(thisParam3, "name", "this")
            listAppend(eqParams, thisParam3)
            val otherParam = mapCreate()
            mapPut(otherParam, "kind", "param")
            mapPut(otherParam, "name", "other")
            listAppend(eqParams, otherParam)
            mapPut(eqDecl, "params", eqParams)
            mapPut(eqDecl, "body", eqBody)
            mapPut(eqDecl, "_className", className)
            mapPut(eqDecl, "_classFields", fieldNames)
            mapPut(eqDecl, "_classMethods", methods)
            compileFunction(compiler, eqDecl)
        }
    }

    // Build type record
    val typeRec = mapCreate()
    val nameIdx = addTypeName(compiler, className)
    mapPut(typeRec, "nameIdx", nameIdx)
    mapPut(typeRec, "fields", fields)
    mapPut(typeRec, "methods", methods)
    listAppend(mapGet(compiler, "types"), typeRec)

    // Register class name (for constructor detection)
    mapPut(mapGet(compiler, "classNames"), className, typeRec)
}

// ---------------------------------------------------------------------------
// Enum compilation — objects with __variant field
// ---------------------------------------------------------------------------

fun compileEnumDecl(compiler: Map, decl: Map): Unit {
    val enumName = toString(mapGet(decl, "name"))
    val entries = mapGet(decl, "entries")
    val entryNames = listCreate()
    if (entries != null) {
        var i: Int = 0
        while (i < listSize(entries)) {
            val entry = listGet(entries, i)
            listAppend(entryNames, toString(mapGet(entry, "name")))
            i = i + 1
        }
    }
    mapPut(mapGet(compiler, "enumNames"), enumName, entryNames)

    // Build type record with __variant field
    val fields = listCreate()
    val variantField = mapCreate()
    mapPut(variantField, "name", "__variant")
    mapPut(variantField, "typeName", "String")
    listAppend(fields, variantField)

    val methodNames = listCreate()

    // Build type record
    val typeRec = mapCreate()
    val nameIdx = addTypeName(compiler, enumName)
    mapPut(typeRec, "nameIdx", nameIdx)
    mapPut(typeRec, "fields", fields)
    mapPut(typeRec, "methods", methodNames)
    listAppend(mapGet(compiler, "types"), typeRec)
    mapPut(mapGet(compiler, "classNames"), enumName, typeRec)

    // Generate initializer function for each entry
    var ei: Int = 0
    while (ei < listSize(entryNames)) {
        val entryName = toString(listGet(entryNames, ei))
        val initName = stringConcat("__init_", stringConcat(enumName, stringConcat("_", entryName)))

        // Build synthetic function body:
        // val v = "EntryName"
        // return NewObject(EnumName, v)
        val stmts = listCreate()

        // val v = "EntryName"
        val valStmt = makeNode("valDecl")
        mapPut(valStmt, "name", "__v")
        val strLit = makeNode("stringLit")
        mapPut(strLit, "value", entryName)
        mapPut(valStmt, "init", strLit)
        listAppend(stmts, valStmt)

        // return EnumName($v)  — constructor call
        val ctorCall = makeNode("call")
        val calleeNode = makeNode("ident")
        mapPut(calleeNode, "name", enumName)
        mapPut(ctorCall, "callee", calleeNode)
        val argList = listCreate()
        val arg1 = mapCreate()
        mapPut(arg1, "kind", "callArg")
        val argVal = makeNode("ident")
        mapPut(argVal, "name", "__v")
        mapPut(arg1, "value", argVal)
        listAppend(argList, arg1)
        mapPut(ctorCall, "args", argList)

        val retNode = makeNode("return")
        mapPut(retNode, "value", ctorCall)
        listAppend(stmts, retNode)

        val bodyBlock = makeNode("block")
        mapPut(bodyBlock, "stmts", stmts)

        val initDecl = mapCreate()
        mapPut(initDecl, "kind", "funDecl")
        mapPut(initDecl, "name", initName)
        mapPut(initDecl, "params", listCreate())
        mapPut(initDecl, "body", bodyBlock)
        compileFunction(compiler, initDecl)

        ei = ei + 1
    }

    // Compile enum methods (same pattern as interface default methods)
    val methods = mapGet(decl, "methods")
    if (methods != null) {
        var mi: Int = 0
        while (mi < listSize(methods)) {
            val member = listGet(methods, mi)
            if (isMap(member)) {
                val mkind = toString(mapGet(member, "kind"))
                if (mkind == "funDecl") {
                    val methodName = toString(mapGet(member, "name"))
                    listAppend(methodNames, methodName)
                    val methodBody = mapGet(member, "body")
                    if (methodBody != null) {
                        val fullName = stringConcat(enumName, stringConcat(".", methodName))
                        val methodParams = listCreate()
                        val thisParam = mapCreate()
                        mapPut(thisParam, "kind", "param")
                        mapPut(thisParam, "name", "this")
                        listAppend(methodParams, thisParam)
                        val origParams = mapGet(member, "params")
                        if (origParams != null) {
                            var pi: Int = 0
                            while (pi < listSize(origParams)) {
                                listAppend(methodParams, listGet(origParams, pi))
                                pi = pi + 1
                            }
                        }
                        val methodDecl = mapCreate()
                        mapPut(methodDecl, "kind", "funDecl")
                        mapPut(methodDecl, "name", fullName)
                        mapPut(methodDecl, "params", methodParams)
                        mapPut(methodDecl, "body", methodBody)
                        mapPut(methodDecl, "returnType", mapGet(member, "returnType"))
                        compileFunction(compiler, methodDecl)
                    }
                }
            }
            mi = mi + 1
        }
    }
}

fun compileInterfaceDecl(compiler: Map, decl: Map): Unit {
    val ifaceName = toString(mapGet(decl, "name"))

    // Register as an interface name
    val methodNames = listCreate()
    mapPut(mapGet(compiler, "interfaceNames"), ifaceName, methodNames)

    // Compile default method implementations
    val body = mapGet(decl, "body")
    if (body != null) {
        val members = mapGet(body, "members")
        if (members != null) {
            var i: Int = 0
            while (i < listSize(members)) {
                val member = listGet(members, i)
                val mkind = toString(mapGet(member, "kind"))
                if (mkind == "funDecl") {
                    val methodName = toString(mapGet(member, "name"))
                    listAppend(methodNames, methodName)
                    // Only compile if it has a body (default implementation)
                    val methodBody = mapGet(member, "body")
                    if (methodBody != null) {
                        val fullName = stringConcat(ifaceName, stringConcat(".", methodName))
                        val methodParams = listCreate()
                        val thisParam = mapCreate()
                        mapPut(thisParam, "kind", "param")
                        mapPut(thisParam, "name", "this")
                        listAppend(methodParams, thisParam)
                        val origParams = mapGet(member, "params")
                        if (origParams != null) {
                            var pi: Int = 0
                            while (pi < listSize(origParams)) {
                                listAppend(methodParams, listGet(origParams, pi))
                                pi = pi + 1
                            }
                        }
                        val methodDecl = mapCreate()
                        mapPut(methodDecl, "kind", "funDecl")
                        mapPut(methodDecl, "name", fullName)
                        mapPut(methodDecl, "params", methodParams)
                        mapPut(methodDecl, "body", methodBody)
                        mapPut(methodDecl, "returnType", mapGet(member, "returnType"))
                        compileFunction(compiler, methodDecl)
                    }
                }
                i = i + 1
            }
        }
    }
}

fun compileObjectDecl(compiler: Map, decl: Map): Unit {
    val objName = toString(mapGet(decl, "name"))

    // Register as an object name for singleton method dispatch
    mapPut(mapGet(compiler, "objectNames"), objName, true)

    // Compile methods in the object body
    val methods = listCreate()
    val body = mapGet(decl, "body")
    if (body != null) {
        val members = mapGet(body, "members")
        var i: Int = 0
        while (i < listSize(members)) {
            val member = listGet(members, i)
            val memberKind = toString(mapGet(member, "kind"))
            if (memberKind == "funDecl") {
                val methodName = toString(mapGet(member, "name"))
                val fullName = stringConcat(objName, stringConcat(".", methodName))
                listAppend(methods, fullName)
                mapPut(member, "name", fullName)
                compileFunction(compiler, member)
            }
            i = i + 1
        }
    }

    // Register type declaration for serialization
    val nameIdx = addTypeName(compiler, objName)
    val typeRec = mapCreate()
    mapPut(typeRec, "nameIdx", nameIdx)
    mapPut(typeRec, "fields", listCreate())
    mapPut(typeRec, "methods", methods)
    listAppend(mapGet(compiler, "types"), typeRec)
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

    // Types
    val types = mapGet(compiler, "types")
    appendU32(bytes, listSize(types))
    var ti: Int = 0
    while (ti < listSize(types)) {
        val typeRec = listGet(types, ti)
        appendU16(bytes, toInt(mapGet(typeRec, "nameIdx")))

        val typeFields = mapGet(typeRec, "fields")
        appendU16(bytes, listSize(typeFields))

        val typeMethods = mapGet(typeRec, "methods")
        appendU16(bytes, listSize(typeMethods))

        // Fields
        var tfi: Int = 0
        while (tfi < listSize(typeFields)) {
            val field = listGet(typeFields, tfi)
            val fname = toString(mapGet(field, "name"))
            val fnameIdx = addFieldName(compiler, fname)
            appendU16(bytes, fnameIdx)
            val ftypeName = toString(mapGet(field, "typeName"))
            if (ftypeName == "Int") { listAppend(bytes, TT_INT()) }
            else { if (ftypeName == "String") { listAppend(bytes, TT_STRING()) }
            else { if (ftypeName == "Bool") { listAppend(bytes, TT_BOOL()) }
            else { if (ftypeName == "Float64") { listAppend(bytes, TT_FLOAT64()) }
            else { listAppend(bytes, TT_UNIT()) } } } }
            tfi = tfi + 1
        }

        // Methods
        var tmi: Int = 0
        while (tmi < listSize(typeMethods)) {
            val mname = toString(listGet(typeMethods, tmi))
            val mnameIdx = addMethodName(compiler, mname)
            appendU16(bytes, mnameIdx)
            tmi = tmi + 1
        }
        ti = ti + 1
    }

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

        // Line table
        val lineTable = mapGet(func, "lineTable")
        if (lineTable != null) {
            appendU32(bytes, listSize(lineTable))
            var li: Int = 0
            while (li < listSize(lineTable)) {
                val entry = listGet(lineTable, li)
                appendU16(bytes, toInt(mapGet(entry, "offset")))
                appendU16(bytes, toInt(mapGet(entry, "line")))
                li = li + 1
            }
        } else {
            appendU32(bytes, 0)
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

    // Pass 1: Register all class, enum, object, and interface names
    var i: Int = 0
    while (i < listSize(decls)) {
        val decl = listGet(decls, i)
        val kind = toString(mapGet(decl, "kind"))
        if (kind == "classDecl") {
            val cname = toString(mapGet(decl, "name"))
            mapPut(mapGet(compiler, "classNames"), cname, true)
            // Register sealed classes
            if (mapGet(decl, "isSealed") == true) {
                mapPut(mapGet(compiler, "sealedNames"), cname, listCreate())
            }
        }
        if (kind == "enumDecl") {
            compileEnumDecl(compiler, decl)
        }
        if (kind == "objectDecl") {
            compileObjectDecl(compiler, decl)
        }
        if (kind == "interfaceDecl") {
            compileInterfaceDecl(compiler, decl)
        }
        if (kind == "typeAlias") {
            val aliasName = toString(mapGet(decl, "name"))
            val targetNode = mapGet(decl, "target")
            val targetName = toString(mapGet(targetNode, "name"))
            mapPut(mapGet(compiler, "typeAliases"), aliasName, targetName)
        }
        i = i + 1
    }

    // Pass 1b: Register subclass relationships
    i = 0
    while (i < listSize(decls)) {
        val decl = listGet(decls, i)
        val kind = toString(mapGet(decl, "kind"))
        if (kind == "classDecl") {
            val superTypes = mapGet(decl, "superTypes")
            if (superTypes != null) {
                val cname = toString(mapGet(decl, "name"))
                var si: Int = 0
                while (si < listSize(superTypes)) {
                    val superType = listGet(superTypes, si)
                    val superName = toString(mapGet(superType, "name"))
                    val sealedSubs = mapGet(mapGet(compiler, "sealedNames"), superName)
                    if (sealedSubs != null) {
                        listAppend(sealedSubs, cname)
                    }
                    si = si + 1
                }
            }
        }
        i = i + 1
    }

    // Pass 1c: Pre-register function signatures for default param padding
    i = 0
    while (i < listSize(decls)) {
        val decl = listGet(decls, i)
        val kind = toString(mapGet(decl, "kind"))
        if (kind == "funDecl") {
            val fname = toString(mapGet(decl, "name"))
            val fparams = mapGet(decl, "params")
            if (fparams != null) {
                mapPut(mapGet(compiler, "funcSignatures"), fname, fparams)
            }
            // Register extension functions
            val recvType = mapGet(decl, "receiverType")
            if (recvType != null) {
                mapPut(mapGet(compiler, "extensionFuncs"), fname, true)
            }
        }
        i = i + 1
    }

    // Pass 2: Compile classes and functions
    i = 0
    while (i < listSize(decls)) {
        val decl = listGet(decls, i)
        val kind = toString(mapGet(decl, "kind"))
        if (kind == "classDecl") {
            compileClassDecl(compiler, decl)
        }
        if (kind == "funDecl") {
            compileFunction(compiler, decl)
        }
        i = i + 1
    }
    return compiler
}

// Get directory of a file path (everything before last '/')
fun dirName(path: String): String {
    val len = stringLength(path)
    var i: Int = len - 1
    while (i >= 0) {
        if (charAt(path, i) == "/") {
            return substring(path, 0, i)
        }
        i = i - 1
    }
    return "."
}

// Resolve an import path like "foo.bar" to a file path
// Searches: 1) relative to source dir, 2) lib path
fun resolveImport(importPath: String, sourceDir: String, libPath: String): String {
    // Convert dots to slashes: "foo.bar.baz" -> "foo/bar/baz"
    var resolved: String = ""
    val len = stringLength(importPath)
    var i: Int = 0
    while (i < len) {
        val ch = charAt(importPath, i)
        if (ch == ".") {
            resolved = stringConcat(resolved, "/")
        } else {
            resolved = stringConcat(resolved, ch)
        }
        i = i + 1
    }

    // Try relative to source dir
    val relPath = stringConcat(sourceDir, stringConcat("/", stringConcat(resolved, ".moon")))
    if (fileExists(relPath)) {
        return relPath
    }

    // Try lib path
    if (stringLength(libPath) > 0) {
        val libFilePath = stringConcat(libPath, stringConcat("/", stringConcat(resolved, ".moon")))
        if (fileExists(libFilePath)) {
            return libFilePath
        }
    }

    return ""
}

// Resolve imports recursively and merge all declarations
fun resolveImports(decls: List, sourceDir: String, libPath: String, imported: Map): List {
    val allDecls = listCreate()
    var i: Int = 0
    while (i < listSize(decls)) {
        val decl = listGet(decls, i)
        val kind = toString(mapGet(decl, "kind"))
        if (kind == "import") {
            val path = toString(mapGet(decl, "path"))
            // Skip wildcard suffix for resolution
            var importPath: String = path
            if (endsWith(importPath, ".*")) {
                importPath = substring(importPath, 0, stringLength(importPath) - 2)
            }
            if (mapGet(imported, importPath) == null) {
                mapPut(imported, importPath, 1)
                val filePath = resolveImport(importPath, sourceDir, libPath)
                if (stringLength(filePath) > 0) {
                    val importSource = toString(fileRead(filePath))
                    val importTokens = tokenize(importSource)
                    val importParser = makeParser(importTokens)
                    val importAst = parseProgram(importParser)
                    val importDecls = mapGet(importAst, "decls")
                    // Recursively resolve imports of the imported file
                    val importDir = dirName(filePath)
                    val resolved = resolveImports(importDecls, importDir, libPath, imported)
                    var j: Int = 0
                    while (j < listSize(resolved)) {
                        listAppend(allDecls, listGet(resolved, j))
                        j = j + 1
                    }
                }
            }
        } else {
            listAppend(allDecls, decl)
        }
        i = i + 1
    }
    return allDecls
}

// ---------------------------------------------------------------------------
// REPL
// ---------------------------------------------------------------------------

fun replMain(): Unit {
    println("Moon REPL (Stage 1) v0.1")
    println("Type :quit to exit, :reset to clear state")
    var topDecls: String = ""
    var mainBody: String = ""

    while (true) {
        print("moon> ")
        val line = readLine()
        if (line == null) { return }
        val trimmed = stringTrim(toString(line))
        if (stringLength(trimmed) == 0) { continue }
        if (trimmed == ":quit") { return }
        if (trimmed == ":q") { return }
        if (trimmed == ":reset") {
            topDecls = ""
            mainBody = ""
            println("State cleared.")
            continue
        }

        // Multi-line support: count braces
        var fullInput: String = toString(line)
        var braceCount: Int = 0
        var ci: Int = 0
        while (ci < stringLength(fullInput)) {
            val ch = charAt(fullInput, ci)
            if (ch == "{") { braceCount = braceCount + 1 }
            if (ch == "}") { braceCount = braceCount - 1 }
            ci = ci + 1
        }
        while (braceCount > 0) {
            print("  ... ")
            val cont = readLine()
            if (cont == null) { return }
            fullInput = stringConcat(fullInput, stringConcat("\n", toString(cont)))
            var ci2: Int = 0
            val contStr = toString(cont)
            while (ci2 < stringLength(contStr)) {
                val ch = charAt(contStr, ci2)
                if (ch == "{") { braceCount = braceCount + 1 }
                if (ch == "}") { braceCount = braceCount - 1 }
                ci2 = ci2 + 1
            }
        }

        // Detect if it's a top-level declaration
        val isTopDecl = startsWith(trimmed, "fun ") || startsWith(trimmed, "class ") ||
                        startsWith(trimmed, "data ") || startsWith(trimmed, "sealed ") ||
                        startsWith(trimmed, "enum ") || startsWith(trimmed, "interface ") ||
                        startsWith(trimmed, "object ")

        val isValVar = startsWith(trimmed, "val ") || startsWith(trimmed, "var ")

        val isStmt = startsWith(trimmed, "println") || startsWith(trimmed, "print(") ||
                     startsWith(trimmed, "if ") || startsWith(trimmed, "if(") ||
                     startsWith(trimmed, "while ") || startsWith(trimmed, "while(") ||
                     startsWith(trimmed, "for ") || startsWith(trimmed, "for(") ||
                     startsWith(trimmed, "return ")

        if (isTopDecl) {
            val newTopDecls = stringConcat(topDecls, stringConcat(fullInput, "\n\n"))
            val source = stringConcat(newTopDecls, stringConcat("fun main(): Unit {\n", stringConcat(mainBody, "}\n")))
            val result = evalMoon(source)
            if (startsWith(result, "ERROR:")) {
                println(result)
            } else {
                topDecls = newTopDecls
                println("OK")
            }
        } else if (isValVar) {
            val newBody = stringConcat(mainBody, stringConcat("    ", stringConcat(fullInput, "\n")))
            val source = stringConcat(topDecls, stringConcat("fun main(): Unit {\n", stringConcat(newBody, "}\n")))
            val result = evalMoon(source)
            if (startsWith(result, "ERROR:")) {
                println(result)
            } else {
                mainBody = newBody
            }
        } else if (isStmt) {
            val stmtBody = stringConcat(mainBody, stringConcat("    ", stringConcat(fullInput, "\n")))
            val source = stringConcat(topDecls, stringConcat("fun main(): Unit {\n", stringConcat(stmtBody, "}\n")))
            val result = evalMoon(source)
            if (startsWith(result, "ERROR:")) {
                println(result)
            } else {
                print(result)
                mainBody = stmtBody
            }
        } else {
            // Try as expression (auto-print)
            val exprBody = stringConcat(mainBody, stringConcat("    println(toString(", stringConcat(fullInput, "))\n")))
            val exprSource = stringConcat(topDecls, stringConcat("fun main(): Unit {\n", stringConcat(exprBody, "}\n")))
            val exprResult = evalMoon(exprSource)
            if (!startsWith(exprResult, "ERROR:")) {
                print(exprResult)
            } else {
                // Fall back to statement
                val stmtBody = stringConcat(mainBody, stringConcat("    ", stringConcat(fullInput, "\n")))
                val stmtSource = stringConcat(topDecls, stringConcat("fun main(): Unit {\n", stringConcat(stmtBody, "}\n")))
                val stmtResult = evalMoon(stmtSource)
                if (startsWith(stmtResult, "ERROR:")) {
                    println(stmtResult)
                } else {
                    print(stmtResult)
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Main entry point
// ---------------------------------------------------------------------------

fun main(): Unit {
    val args = processArgs()
    if (listSize(args) < 1) {
        println("Usage: moonc compile <source.moon> [output.moonb] [--no-check] [--lib-path <path>]")
        println("       moonc repl")
        return
    }

    val command = toString(listGet(args, 0))

    // REPL mode
    if (command == "repl") {
        replMain()
        return
    }

    if (listSize(args) < 2) {
        println("Usage: moonc compile <source.moon> [output.moonb] [--no-check] [--lib-path <path>]")
        println("       moonc repl")
        return
    }
    var sourceFile: String = toString(listGet(args, 1))
    var outputFile: String = ""
    var libPath: String = ""

    // Parse remaining args
    var ai: Int = 2
    while (ai < listSize(args)) {
        val arg = toString(listGet(args, ai))
        if (arg == "--lib-path") {
            if (ai + 1 < listSize(args)) {
                ai = ai + 1
                libPath = toString(listGet(args, ai))
            }
        } else {
            if (stringLength(outputFile) == 0) {
                outputFile = arg
            }
        }
        ai = ai + 1
    }

    // Determine output file
    if (stringLength(outputFile) == 0) {
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
        println(stringConcat(sourceFile, stringConcat(": ", stringConcat(toString(listSize(errors)), " parse error(s):"))))
        var i: Int = 0
        while (i < listSize(errors)) {
            println(stringConcat("  ", toString(listGet(errors, i))))
            i = i + 1
        }
        return
    }

    // Resolve imports
    val sourceDir = dirName(sourceFile)
    val imported = mapCreate()
    val rawDecls = mapGet(ast, "decls")
    val resolvedDecls = resolveImports(rawDecls, sourceDir, libPath, imported)
    mapPut(ast, "decls", resolvedDecls)

    // Type check (default on, --no-check to disable)
    var doCheck: Bool = true
    var ac: Int = 2
    while (ac < listSize(args)) {
        if (toString(listGet(args, ac)) == "--no-check") { doCheck = false }
        ac = ac + 1
    }
    if (doCheck) {
        val tc = typeCheckWithFile(ast, sourceFile)
        val tcErrors = mapGet(tc, "errors")
        if (listSize(tcErrors) > 0) {
            var ei: Int = 0
            while (ei < listSize(tcErrors)) {
                println(stringConcat("warning: ", toString(listGet(tcErrors, ei))))
                ei = ei + 1
            }
            println(stringConcat(toString(listSize(tcErrors)), " type warning(s)"))
        }
    }

    // Optimize (opt-in with --optimize)
    var doOptimize: Bool = false
    var oi: Int = 2
    while (oi < listSize(args)) {
        if (toString(listGet(args, oi)) == "--optimize") { doOptimize = true }
        oi = oi + 1
    }
    if (doOptimize) {
        foldConstants(ast)
    }

    // Compile
    val compiler = compileProgram(ast)

    // Dead function elimination (always on — safe and reduces output size)
    eliminateDeadFunctions(compiler)

    // Serialize
    val moduleBytes = serializeModule(compiler)

    // Write
    fileWriteBytes(outputFile, moduleBytes)

    val funcCount = listSize(mapGet(compiler, "functions"))
    val byteCount = listSize(moduleBytes)
    println(stringConcat(sourceFile, stringConcat(" -> ", outputFile)))
    println(stringConcat("  ", stringConcat(toString(funcCount), stringConcat(" function(s), ", stringConcat(toString(byteCount), " bytes")))))
}
