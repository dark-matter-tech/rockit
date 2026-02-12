// Stage 1 Type Checker — Moon-native type checking
// Two-pass approach: 1) gather declarations, 2) check bodies

// ---------------------------------------------------------------------------
// Type checker state
// ---------------------------------------------------------------------------

fun makeTypeChecker(ast: Map): Map {
    val tc = mapCreate()
    mapPut(tc, "ast", ast)
    // Function signatures: name -> {params: List<String>, returnType: String}
    mapPut(tc, "functions", mapCreate())
    // Class declarations: name -> {fields: Map<name, type>}
    mapPut(tc, "classes", mapCreate())
    // Scope stack: list of maps (variable name -> type string)
    mapPut(tc, "scopes", listCreate())
    // Errors: list of error message strings
    mapPut(tc, "errors", listCreate())
    // Warnings: list of warning message strings
    mapPut(tc, "warnings", listCreate())
    return tc
}

fun tcPushScope(tc: Map): Unit {
    listAppend(mapGet(tc, "scopes"), mapCreate())
}

fun tcPopScope(tc: Map): Unit {
    val scopes = mapGet(tc, "scopes")
    listRemoveAt(scopes, listSize(scopes) - 1)
}

fun tcDefine(tc: Map, name: String, type: String): Unit {
    val scopes = mapGet(tc, "scopes")
    if (listSize(scopes) > 0) {
        val top = listGet(scopes, listSize(scopes) - 1)
        mapPut(top, name, type)
    }
}

fun tcLookup(tc: Map, name: String): String {
    val scopes = mapGet(tc, "scopes")
    var i: Int = listSize(scopes) - 1
    while (i >= 0) {
        val scope = listGet(scopes, i)
        val t = mapGet(scope, name)
        if (t != null) { return toString(t) }
        i = i - 1
    }
    return ""
}

fun tcError(tc: Map, msg: String, node: Map): Unit {
    val line = toInt(mapGet(node, "line"))
    val col = toInt(mapGet(node, "col"))
    val full = stringConcat(toString(line), stringConcat(":", stringConcat(toString(col), stringConcat(": error: ", msg))))
    listAppend(mapGet(tc, "errors"), full)
}

fun tcWarn(tc: Map, msg: String, node: Map): Unit {
    val line = toInt(mapGet(node, "line"))
    val col = toInt(mapGet(node, "col"))
    val full = stringConcat(toString(line), stringConcat(":", stringConcat(toString(col), stringConcat(": warning: ", msg))))
    listAppend(mapGet(tc, "warnings"), full)
}

// ---------------------------------------------------------------------------
// Builtin function registration
// ---------------------------------------------------------------------------

fun registerBuiltins(tc: Map): Unit {
    val fns = mapGet(tc, "functions")

    // I/O
    registerFn(fns, "println", 1, "Unit")
    registerFn(fns, "print", 1, "Unit")
    registerFn(fns, "readLine", 0, "String")

    // Conversion
    registerFn(fns, "toString", 1, "String")
    registerFn(fns, "toInt", 1, "Int")
    registerFn(fns, "intToString", 1, "String")
    registerFn(fns, "floatToString", 1, "String")

    // String operations
    registerFn(fns, "stringLength", 1, "Int")
    registerFn(fns, "stringSubstring", 3, "String")
    registerFn(fns, "charAt", 2, "String")
    registerFn(fns, "charCodeAt", 2, "Int")
    registerFn(fns, "substring", 3, "String")
    registerFn(fns, "stringIndexOf", 2, "Int")
    registerFn(fns, "startsWith", 2, "Bool")
    registerFn(fns, "endsWith", 2, "Bool")
    registerFn(fns, "stringContains", 2, "Bool")
    registerFn(fns, "stringTrim", 1, "String")
    registerFn(fns, "stringReplace", 3, "String")
    registerFn(fns, "stringToLower", 1, "String")
    registerFn(fns, "stringToUpper", 1, "String")
    registerFn(fns, "stringConcat", 2, "String")
    registerFn(fns, "stringSplit", 2, "List")
    registerFn(fns, "stringFromCharCodes", 1, "String")

    // Char operations
    registerFn(fns, "isDigit", 1, "Bool")
    registerFn(fns, "isLetter", 1, "Bool")
    registerFn(fns, "isWhitespace", 1, "Bool")
    registerFn(fns, "isLetterOrDigit", 1, "Bool")
    registerFn(fns, "charToInt", 1, "Int")
    registerFn(fns, "intToChar", 1, "String")

    // Math
    registerFn(fns, "abs", 1, "Int")
    registerFn(fns, "min", 2, "Int")
    registerFn(fns, "max", 2, "Int")

    // List operations
    registerFn(fns, "listCreate", 0, "List")
    registerFn(fns, "listAppend", 2, "Unit")
    registerFn(fns, "listGet", 2, "Any")
    registerFn(fns, "listSet", 3, "Unit")
    registerFn(fns, "listSize", 1, "Int")
    registerFn(fns, "listRemoveAt", 2, "Any")
    registerFn(fns, "listContains", 2, "Bool")
    registerFn(fns, "listIndexOf", 2, "Int")
    registerFn(fns, "listIsEmpty", 1, "Bool")
    registerFn(fns, "listClear", 1, "Unit")

    // Map operations
    registerFn(fns, "mapCreate", 0, "Map")
    registerFn(fns, "mapPut", 3, "Unit")
    registerFn(fns, "mapGet", 2, "Any")
    registerFn(fns, "mapRemove", 2, "Any")
    registerFn(fns, "mapContainsKey", 2, "Bool")
    registerFn(fns, "mapKeys", 1, "List")
    registerFn(fns, "mapValues", 1, "List")
    registerFn(fns, "mapSize", 1, "Int")
    registerFn(fns, "mapIsEmpty", 1, "Bool")
    registerFn(fns, "mapClear", 1, "Unit")

    // File I/O
    registerFn(fns, "fileRead", 1, "String")
    registerFn(fns, "fileWrite", 2, "Bool")
    registerFn(fns, "fileExists", 1, "Bool")
    registerFn(fns, "fileDelete", 1, "Bool")
    registerFn(fns, "fileWriteBytes", 2, "Bool")

    // Process
    registerFn(fns, "processArgs", 0, "List")
    registerFn(fns, "processExit", 1, "Unit")
    registerFn(fns, "getEnv", 1, "String")

    // Misc
    registerFn(fns, "panic", 1, "Unit")
    registerFn(fns, "typeOf", 1, "String")
}

fun registerFn(fns: Map, name: String, arity: Int, ret: String): Unit {
    val sig = mapCreate()
    mapPut(sig, "arity", arity)
    mapPut(sig, "returnType", ret)
    mapPut(sig, "variadic", false)
    mapPut(fns, name, sig)
}

// ---------------------------------------------------------------------------
// Pass 1: Gather declarations
// ---------------------------------------------------------------------------

fun tcGatherDecls(tc: Map): Unit {
    val ast = mapGet(tc, "ast")
    val decls = mapGet(ast, "decls")
    if (decls == null) { return }
    var i: Int = 0
    while (i < listSize(decls)) {
        tcGatherDecl(tc, listGet(decls, i))
        i = i + 1
    }
}

fun tcGatherDecl(tc: Map, decl: Map): Unit {
    if (decl == null) { return }
    val kind = toString(mapGet(decl, "kind"))

    if (kind == "funDecl") {
        val name = toString(mapGet(decl, "name"))
        val params = mapGet(decl, "params")
        var arity: Int = 0
        if (params != null) { arity = listSize(params) }
        val retTypeNode = mapGet(decl, "returnType")
        var ret: String = "Unit"
        if (retTypeNode != null) { ret = resolveTypeName(retTypeNode) }
        val sig = mapCreate()
        mapPut(sig, "arity", arity)
        mapPut(sig, "returnType", ret)
        mapPut(sig, "variadic", false)
        mapPut(sig, "params", params)
        mapPut(mapGet(tc, "functions"), name, sig)
    } else if (kind == "classDecl") {
        val name = toString(mapGet(decl, "name"))
        val classInfo = mapCreate()
        val fields = mapCreate()
        // Register constructor params as fields
        val params = mapGet(decl, "params")
        if (params != null) {
            var j: Int = 0
            while (j < listSize(params)) {
                val p = listGet(params, j)
                val pname = toString(mapGet(p, "name"))
                val ptype = mapGet(p, "type")
                mapPut(fields, pname, if (ptype != null) { resolveTypeName(ptype) } else { "Any" })
                j = j + 1
            }
        }
        mapPut(classInfo, "fields", fields)
        mapPut(mapGet(tc, "classes"), name, classInfo)

        // Register constructor as a function
        val ctorSig = mapCreate()
        var ctorArity: Int = 0
        if (params != null) { ctorArity = listSize(params) }
        mapPut(ctorSig, "arity", ctorArity)
        mapPut(ctorSig, "returnType", name)
        mapPut(ctorSig, "variadic", false)
        mapPut(mapGet(tc, "functions"), name, ctorSig)

        // Register methods
        val members = mapGet(decl, "members")
        if (members != null) {
            var j: Int = 0
            while (j < listSize(members)) {
                val member = listGet(members, j)
                if (toString(mapGet(member, "kind")) == "funDecl") {
                    val mname = toString(mapGet(member, "name"))
                    val fullName = stringConcat(name, stringConcat(".", mname))
                    val mparams = mapGet(member, "params")
                    var marity: Int = 0
                    if (mparams != null) { marity = listSize(mparams) }
                    val mret = mapGet(member, "returnType")
                    val msig = mapCreate()
                    mapPut(msig, "arity", marity + 1)
                    mapPut(msig, "returnType", if (mret != null) { resolveTypeName(mret) } else { "Unit" })
                    mapPut(msig, "variadic", false)
                    mapPut(mapGet(tc, "functions"), fullName, msig)
                }
                j = j + 1
            }
        }
    } else if (kind == "enumDecl") {
        val name = toString(mapGet(decl, "name"))
        mapPut(mapGet(tc, "classes"), name, mapCreate())
    } else if (kind == "objectDecl") {
        val name = toString(mapGet(decl, "name"))
        mapPut(mapGet(tc, "classes"), name, mapCreate())
    } else if (kind == "interfaceDecl") {
        val name = toString(mapGet(decl, "name"))
        mapPut(mapGet(tc, "classes"), name, mapCreate())
    }
}

fun resolveTypeName(typeNode: Map): String {
    if (typeNode == null) { return "Any" }
    val kind = toString(mapGet(typeNode, "kind"))
    if (kind == "simpleType") {
        val name = toString(mapGet(typeNode, "name"))
        val nullable = mapGet(typeNode, "nullable")
        if (nullable == true) {
            return stringConcat(name, "?")
        }
        return name
    } else if (kind == "functionType") {
        return "Function"
    }
    return "Any"
}

// ---------------------------------------------------------------------------
// Pass 2: Check function bodies
// ---------------------------------------------------------------------------

fun tcCheckBodies(tc: Map): Unit {
    val ast = mapGet(tc, "ast")
    val decls = mapGet(ast, "decls")
    if (decls == null) { return }
    var i: Int = 0
    while (i < listSize(decls)) {
        tcCheckDecl(tc, listGet(decls, i))
        i = i + 1
    }
}

fun tcCheckDecl(tc: Map, decl: Map): Unit {
    if (decl == null) { return }
    val kind = toString(mapGet(decl, "kind"))

    if (kind == "funDecl") {
        tcPushScope(tc)
        // Register parameters
        val params = mapGet(decl, "params")
        if (params != null) {
            var i: Int = 0
            while (i < listSize(params)) {
                val p = listGet(params, i)
                val pname = toString(mapGet(p, "name"))
                val ptype = mapGet(p, "type")
                var typeName: String = "Any"
                if (ptype != null) { typeName = resolveTypeName(ptype) }
                tcDefine(tc, pname, typeName)
                i = i + 1
            }
        }
        // Check body
        val body = mapGet(decl, "body")
        if (body != null) {
            val stmts = mapGet(body, "stmts")
            if (stmts != null) {
                tcCheckStmts(tc, stmts)
            }
        }
        tcPopScope(tc)
    } else if (kind == "classDecl") {
        // Check methods
        val members = mapGet(decl, "members")
        if (members != null) {
            var i: Int = 0
            while (i < listSize(members)) {
                val member = listGet(members, i)
                if (toString(mapGet(member, "kind")) == "funDecl") {
                    tcPushScope(tc)
                    val name = toString(mapGet(decl, "name"))
                    tcDefine(tc, "this", name)
                    // Register class fields in scope
                    val params = mapGet(decl, "params")
                    if (params != null) {
                        var j: Int = 0
                        while (j < listSize(params)) {
                            val p = listGet(params, j)
                            val pname = toString(mapGet(p, "name"))
                            val ptype = mapGet(p, "type")
                            tcDefine(tc, pname, if (ptype != null) { resolveTypeName(ptype) } else { "Any" })
                            j = j + 1
                        }
                    }
                    tcCheckDecl(tc, member)
                    tcPopScope(tc)
                }
                i = i + 1
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Statement checking
// ---------------------------------------------------------------------------

fun tcCheckStmts(tc: Map, stmts: List): Unit {
    var i: Int = 0
    while (i < listSize(stmts)) {
        tcCheckStmt(tc, listGet(stmts, i))
        i = i + 1
    }
}

fun tcCheckStmt(tc: Map, stmt: Map): Unit {
    if (stmt == null) { return }
    if (!isMap(stmt)) { return }
    val kind = toString(mapGet(stmt, "kind"))

    if (kind == "valDecl") {
        val name = toString(mapGet(stmt, "name"))
        val typeAnnotation = mapGet(stmt, "type")
        val initExpr = mapGet(stmt, "init")
        var declaredType: String = ""
        if (typeAnnotation != null) {
            declaredType = resolveTypeName(typeAnnotation)
        }
        if (initExpr != null) {
            val inferredType = tcInferExpr(tc, initExpr)
            if (declaredType == "") {
                declaredType = inferredType
            } else if (inferredType != "Any" && declaredType != "Any" && inferredType != declaredType) {
                if (!tcTypesCompatible(declaredType, inferredType)) {
                    tcError(tc, stringConcat("type mismatch: expected ", stringConcat(declaredType, stringConcat(" but got ", inferredType))), stmt)
                }
            }
        }
        if (declaredType == "") { declaredType = "Any" }
        tcDefine(tc, name, declaredType)
    } else if (kind == "varDecl") {
        val name = toString(mapGet(stmt, "name"))
        val typeAnnotation = mapGet(stmt, "type")
        val initExpr = mapGet(stmt, "init")
        var declaredType: String = ""
        if (typeAnnotation != null) {
            declaredType = resolveTypeName(typeAnnotation)
        }
        if (initExpr != null) {
            val inferredType = tcInferExpr(tc, initExpr)
            if (declaredType == "") {
                declaredType = inferredType
            } else if (inferredType != "Any" && declaredType != "Any" && inferredType != declaredType) {
                if (!tcTypesCompatible(declaredType, inferredType)) {
                    tcError(tc, stringConcat("type mismatch: expected ", stringConcat(declaredType, stringConcat(" but got ", inferredType))), stmt)
                }
            }
        }
        if (declaredType == "") { declaredType = "Any" }
        tcDefine(tc, name, declaredType)
    } else if (kind == "assign") {
        val target = mapGet(stmt, "target")
        val value = mapGet(stmt, "value")
        if (target != null && value != null) {
            tcInferExpr(tc, target)
            tcInferExpr(tc, value)
        }
    } else if (kind == "compoundAssign") {
        val target = mapGet(stmt, "target")
        val value = mapGet(stmt, "value")
        if (target != null && value != null) {
            tcInferExpr(tc, target)
            tcInferExpr(tc, value)
        }
    } else if (kind == "return") {
        val value = mapGet(stmt, "value")
        if (value != null) {
            tcInferExpr(tc, value)
        }
    } else if (kind == "if") {
        val condition = mapGet(stmt, "condition")
        if (condition != null) {
            val condType = tcInferExpr(tc, condition)
            if (condType != "Bool" && condType != "Any") {
                tcError(tc, stringConcat("if condition must be Bool, got ", condType), stmt)
            }
        }
        val thenBody = mapGet(stmt, "then")
        if (thenBody != null) {
            tcPushScope(tc)
            val stmts = mapGet(thenBody, "stmts")
            if (stmts != null) { tcCheckStmts(tc, stmts) }
            tcPopScope(tc)
        }
        val elseBody = mapGet(stmt, "else")
        if (elseBody != null) {
            tcPushScope(tc)
            val eStmts = mapGet(elseBody, "stmts")
            if (eStmts != null) { tcCheckStmts(tc, eStmts) }
            tcPopScope(tc)
        }
    } else if (kind == "while") {
        val condition = mapGet(stmt, "condition")
        if (condition != null) {
            val condType = tcInferExpr(tc, condition)
            if (condType != "Bool" && condType != "Any") {
                tcError(tc, stringConcat("while condition must be Bool, got ", condType), stmt)
            }
        }
        val body = mapGet(stmt, "body")
        if (body != null) {
            tcPushScope(tc)
            val stmts = mapGet(body, "stmts")
            if (stmts != null) { tcCheckStmts(tc, stmts) }
            tcPopScope(tc)
        }
    } else if (kind == "for") {
        tcPushScope(tc)
        val varName = toString(mapGet(stmt, "variable"))
        val iterable = mapGet(stmt, "iterable")
        if (iterable != null) {
            tcInferExpr(tc, iterable)
        }
        tcDefine(tc, varName, "Any")
        val body = mapGet(stmt, "body")
        if (body != null) {
            val stmts = mapGet(body, "stmts")
            if (stmts != null) { tcCheckStmts(tc, stmts) }
        }
        tcPopScope(tc)
    } else if (kind == "throw") {
        val value = mapGet(stmt, "value")
        if (value != null) { tcInferExpr(tc, value) }
    } else if (kind == "try") {
        val tryBody = mapGet(stmt, "tryBody")
        if (tryBody != null) {
            tcPushScope(tc)
            val stmts = mapGet(tryBody, "stmts")
            if (stmts != null) { tcCheckStmts(tc, stmts) }
            tcPopScope(tc)
        }
        val catchBody = mapGet(stmt, "catchBody")
        if (catchBody != null) {
            tcPushScope(tc)
            val catchVar = mapGet(stmt, "catchVar")
            if (catchVar != null) { tcDefine(tc, toString(catchVar), "Any") }
            val cStmts = mapGet(catchBody, "stmts")
            if (cStmts != null) { tcCheckStmts(tc, cStmts) }
            tcPopScope(tc)
        }
    } else if (kind == "funDecl") {
        // Nested function
        tcGatherDecl(tc, stmt)
        tcCheckDecl(tc, stmt)
    } else if (kind == "destructure") {
        val names = mapGet(stmt, "names")
        val initExpr = mapGet(stmt, "init")
        if (initExpr != null) { tcInferExpr(tc, initExpr) }
        if (names != null) {
            var i: Int = 0
            while (i < listSize(names)) {
                tcDefine(tc, toString(listGet(names, i)), "Any")
                i = i + 1
            }
        }
    } else {
        // Bare expression statement
        tcInferExpr(tc, stmt)
    }
}

// ---------------------------------------------------------------------------
// Expression type inference
// ---------------------------------------------------------------------------

fun tcInferExpr(tc: Map, expr: Map): String {
    if (expr == null) { return "Any" }
    if (!isMap(expr)) { return "Any" }
    val kind = toString(mapGet(expr, "kind"))

    if (kind == "intLiteral") { return "Int" }
    if (kind == "floatLiteral") { return "Float" }
    if (kind == "stringLiteral") { return "String" }
    if (kind == "boolLiteral") { return "Bool" }
    if (kind == "nullLiteral") { return "Null" }
    if (kind == "interpolatedString") { return "String" }

    if (kind == "ident") {
        val name = toString(mapGet(expr, "name"))
        val t = tcLookup(tc, name)
        if (t != "") { return t }
        // Could be a function reference
        val fns = mapGet(tc, "functions")
        if (mapGet(fns, name) != null) { return "Function" }
        // Don't error here — could be a builtin or external
        return "Any"
    }

    if (kind == "binary") {
        val left = mapGet(expr, "left")
        val right = mapGet(expr, "right")
        val op = toString(mapGet(expr, "op"))
        val leftType = tcInferExpr(tc, left)
        val rightType = tcInferExpr(tc, right)

        // Comparison operators
        if (op == "==" || op == "!=" || op == ">" || op == "<" || op == ">=" || op == "<=") {
            return "Bool"
        }
        // Boolean operators
        if (op == "&&" || op == "||") {
            if (leftType != "Bool" && leftType != "Any") {
                tcError(tc, stringConcat("boolean operator requires Bool, got ", leftType), expr)
            }
            if (rightType != "Bool" && rightType != "Any") {
                tcError(tc, stringConcat("boolean operator requires Bool, got ", rightType), expr)
            }
            return "Bool"
        }
        // Arithmetic operators
        if (op == "+" || op == "-" || op == "*" || op == "/" || op == "%") {
            if (leftType == "String" && op == "+") { return "String" }
            if (leftType == "Int" && rightType == "Int") { return "Int" }
            if (leftType == "Float" || rightType == "Float") { return "Float" }
            if (leftType == "Any" || rightType == "Any") { return "Any" }
            return "Int"
        }
        return "Any"
    }

    if (kind == "unary") {
        val operand = mapGet(expr, "operand")
        val op = toString(mapGet(expr, "op"))
        val operandType = tcInferExpr(tc, operand)
        if (op == "!") { return "Bool" }
        if (op == "-") { return operandType }
        return operandType
    }

    if (kind == "call") {
        val callee = mapGet(expr, "callee")
        val args = mapGet(expr, "args")
        var argCount: Int = 0
        if (args != null) { argCount = listSize(args) }

        // Check arguments
        if (args != null) {
            var i: Int = 0
            while (i < listSize(args)) {
                val arg = listGet(args, i)
                val argValue = mapGet(arg, "value")
                if (argValue != null) { tcInferExpr(tc, argValue) }
                i = i + 1
            }
        }

        // Resolve function name
        if (callee != null && toString(mapGet(callee, "kind")) == "ident") {
            val fname = toString(mapGet(callee, "name"))
            val fns = mapGet(tc, "functions")
            val sig = mapGet(fns, fname)
            if (sig != null) {
                val expectedArity = toInt(mapGet(sig, "arity"))
                // Only check arity for non-variadic functions with known arity
                if (expectedArity >= 0 && argCount != expectedArity) {
                    // Allow default parameters — don't error if fewer args
                    if (argCount > expectedArity) {
                        tcError(tc, stringConcat(fname, stringConcat(" expects ", stringConcat(toString(expectedArity), stringConcat(" argument(s), got ", toString(argCount))))), expr)
                    }
                }
                return toString(mapGet(sig, "returnType"))
            }
            // Check if it's a class constructor
            val classes = mapGet(tc, "classes")
            if (mapGet(classes, fname) != null) {
                return fname
            }
            return "Any"
        }

        // Method call on member access
        if (callee != null && toString(mapGet(callee, "kind")) == "member") {
            tcInferExpr(tc, mapGet(callee, "object"))
            return "Any"
        }

        // Indirect call
        if (callee != null) { tcInferExpr(tc, callee) }
        return "Any"
    }

    if (kind == "member") {
        val obj = mapGet(expr, "object")
        if (obj != null) { tcInferExpr(tc, obj) }
        return "Any"
    }

    if (kind == "subscript") {
        val obj = mapGet(expr, "object")
        val index = mapGet(expr, "index")
        if (obj != null) { tcInferExpr(tc, obj) }
        if (index != null) { tcInferExpr(tc, index) }
        return "Any"
    }

    if (kind == "if") {
        val condition = mapGet(expr, "condition")
        if (condition != null) {
            val condType = tcInferExpr(tc, condition)
            if (condType != "Bool" && condType != "Any") {
                tcError(tc, stringConcat("if condition must be Bool, got ", condType), expr)
            }
        }
        val thenBody = mapGet(expr, "then")
        if (thenBody != null) {
            tcPushScope(tc)
            val stmts = mapGet(thenBody, "stmts")
            if (stmts != null) { tcCheckStmts(tc, stmts) }
            tcPopScope(tc)
        }
        val elseBody = mapGet(expr, "else")
        if (elseBody != null) {
            tcPushScope(tc)
            val eStmts = mapGet(elseBody, "stmts")
            if (eStmts != null) { tcCheckStmts(tc, eStmts) }
            tcPopScope(tc)
        }
        return "Any"
    }

    if (kind == "when") {
        val subject = mapGet(expr, "subject")
        if (subject != null) { tcInferExpr(tc, subject) }
        val entries = mapGet(expr, "entries")
        if (entries != null) {
            var i: Int = 0
            while (i < listSize(entries)) {
                val entry = listGet(entries, i)
                val conditions = mapGet(entry, "conditions")
                if (conditions != null) {
                    var j: Int = 0
                    while (j < listSize(conditions)) {
                        val cond = listGet(conditions, j)
                        if (cond != null) { tcInferExpr(tc, cond) }
                        j = j + 1
                    }
                }
                val body = mapGet(entry, "body")
                if (body != null) {
                    val bStmts = mapGet(body, "stmts")
                    if (bStmts != null) { tcCheckStmts(tc, bStmts) }
                }
                i = i + 1
            }
        }
        return "Any"
    }

    if (kind == "lambda") {
        return "Function"
    }

    if (kind == "elvis") {
        val left = mapGet(expr, "left")
        val right = mapGet(expr, "right")
        if (left != null) { tcInferExpr(tc, left) }
        if (right != null) { return tcInferExpr(tc, right) }
        return "Any"
    }

    if (kind == "nonNullAssert") {
        val inner = mapGet(expr, "expr")
        if (inner != null) {
            val t = tcInferExpr(tc, inner)
            // Strip nullable
            if (endsWith(t, "?")) {
                return substring(t, 0, stringLength(t) - 1)
            }
            return t
        }
        return "Any"
    }

    if (kind == "range") {
        val start = mapGet(expr, "start")
        val end = mapGet(expr, "end")
        if (start != null) { tcInferExpr(tc, start) }
        if (end != null) { tcInferExpr(tc, end) }
        return "Range"
    }

    if (kind == "paren") {
        val inner = mapGet(expr, "expr")
        if (inner != null) { return tcInferExpr(tc, inner) }
        return "Any"
    }

    if (kind == "typeCheck") {
        val inner = mapGet(expr, "expr")
        if (inner != null) { tcInferExpr(tc, inner) }
        return "Bool"
    }

    if (kind == "typeCast") {
        val inner = mapGet(expr, "expr")
        if (inner != null) { tcInferExpr(tc, inner) }
        val targetType = mapGet(expr, "targetType")
        if (targetType != null) { return resolveTypeName(targetType) }
        return "Any"
    }

    // Default: bare expression in statement position
    return "Any"
}

// ---------------------------------------------------------------------------
// Type compatibility
// ---------------------------------------------------------------------------

fun tcTypesCompatible(expected: String, actual: String): Bool {
    if (expected == actual) { return true }
    if (expected == "Any" || actual == "Any") { return true }
    if (actual == "Null") {
        // Null is compatible with nullable types
        return endsWith(expected, "?")
    }
    // Int and Float are somewhat compatible
    if (expected == "Float" && actual == "Int") { return true }
    if (expected == "Int" && actual == "Float") { return true }
    // Nullable compatibility
    if (endsWith(expected, "?")) {
        val base = substring(expected, 0, stringLength(expected) - 1)
        if (base == actual) { return true }
    }
    return false
}

// ---------------------------------------------------------------------------
// Main entry point
// ---------------------------------------------------------------------------

fun typeCheck(ast: Map): Map {
    val tc = makeTypeChecker(ast)
    registerBuiltins(tc)
    tcGatherDecls(tc)
    tcCheckBodies(tc)
    return tc
}
