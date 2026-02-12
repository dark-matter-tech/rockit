// MIRLowering.swift
// MoonKit — Moon Language Compiler
// Copyright © 2026 Dark Matter Tech. All rights reserved.

// MARK: - MIR Lowering

/// Lowers a type-checked AST into MIR (Moon Intermediate Representation).
/// Produces a `MIRModule` containing functions, globals, and type declarations.
public final class MIRLowering {
    private let result: TypeCheckResult
    private let diagnostics: DiagnosticEngine
    private var builder = MIRBuilder()

    /// Maps local variable names to their alloc temps
    private var locals: [String: String] = [:]

    /// The current class name (for method name mangling)
    private var currentClassName: String?

    /// Stack of (continueLabel, breakLabel) for loop break/continue support
    private var loopStack: [(continueLabel: String, breakLabel: String)] = []

    /// Accumulated module components
    private var functions: [MIRFunction] = []
    private var globals: [MIRGlobal] = []
    private var typeDecls: [MIRTypeDecl] = []

    public init(typeCheckResult: TypeCheckResult) {
        self.result = typeCheckResult
        self.diagnostics = typeCheckResult.diagnostics
    }

    /// Lower the entire AST to a MIR module.
    public func lower() -> MIRModule {
        for decl in result.ast.declarations {
            lowerDeclaration(decl)
        }
        return MIRModule(globals: globals, functions: functions, types: typeDecls)
    }

    // MARK: - Declaration Lowering

    private func lowerDeclaration(_ decl: Declaration) {
        switch decl {
        case .function(let f):
            lowerFunction(f)
        case .property(let p):
            lowerTopLevelProperty(p)
        case .classDecl(let c):
            lowerClass(c)
        case .interfaceDecl(let i):
            lowerInterface(i)
        case .enumDecl(let e):
            lowerEnum(e)
        case .objectDecl(let o):
            lowerObject(o)
        case .actorDecl(let a):
            lowerActor(a)
        case .viewDecl(let v):
            lowerView(v)
        case .navigationDecl(let n):
            lowerNavigation(n)
        case .themeDecl(let t):
            lowerTheme(t)
        case .typeAlias:
            break
        }
    }

    // MARK: - Function Lowering

    private func lowerFunction(_ f: FunctionDecl) {
        let savedLocals = locals
        locals = [:]

        let params: [(String, MIRType)] = f.parameters.map { p in
            let type: MIRType
            if let typeNode = p.type {
                let resolved = result.symbolTable.lookup(p.name)?.type ?? .error
                type = MIRType.from(resolved)
                _ = typeNode // suppress unused warning
            } else {
                type = .unit
            }
            return (p.name, type)
        }

        let retType: MIRType
        if let sym = result.symbolTable.lookup(f.name),
           case .function(_, let rt) = sym.type {
            retType = MIRType.from(rt)
        } else {
            retType = .unit
        }

        let funcName: String
        if let className = currentClassName {
            funcName = "\(className).\(f.name)"
        } else {
            funcName = f.name
        }

        builder.startBlock(label: "entry")

        // Alloc and store each parameter
        for (name, type) in params {
            let slot = builder.emitAlloc(type: type)
            locals[name] = slot
            // Parameters are available as their name; store the param value
            let paramTemp = builder.newTemp()
            builder.emit(.load(dest: paramTemp, src: "param.\(name)"))
            builder.emitStore(dest: slot, src: paramTemp)
        }

        // Lower body
        if let body = f.body {
            switch body {
            case .block(let block):
                lowerBlock(block)
            case .expression(let expr):
                let val = lowerExpression(expr)
                if !builder.isTerminated {
                    builder.terminate(.ret(val))
                }
            }
        }

        // Ensure terminator
        if !builder.isTerminated {
            builder.terminate(.ret(nil))
        }

        let blocks = builder.finishBlocks()
        let mirFunc = MIRFunction(name: funcName, parameters: params, returnType: retType, blocks: blocks)
        functions.append(mirFunc)

        locals = savedLocals
    }

    // MARK: - Top-Level Property

    private func lowerTopLevelProperty(_ p: PropertyDecl) {
        let type: MIRType
        if let sym = result.symbolTable.lookup(p.name) {
            type = MIRType.from(sym.type)
        } else {
            type = .unit
        }

        let isMutable = !p.isVal
        var initFunc: String? = nil

        if p.initializer != nil {
            // Create an initializer function
            let initName = "__init_\(p.name)"
            initFunc = initName

            let savedLocals = locals
            locals = [:]
            builder.startBlock(label: "entry")

            let val = lowerExpression(p.initializer!)
            builder.terminate(.ret(val))

            let blocks = builder.finishBlocks()
            let mirFunc = MIRFunction(name: initName, parameters: [], returnType: type, blocks: blocks)
            functions.append(mirFunc)
            locals = savedLocals
        }

        globals.append(MIRGlobal(name: p.name, type: type, isMutable: isMutable, initializerFunc: initFunc))
    }

    // MARK: - Class Lowering

    private func lowerClass(_ c: ClassDecl) {
        // Build MIRTypeDecl
        var fields: [(String, MIRType)] = []
        var methodNames: [String] = []

        for param in c.constructorParams {
            if param.isVal || param.isVar {
                let paramType: MIRType
                if let sym = result.symbolTable.lookupType(c.name),
                   let memberSym = sym.members.first(where: { $0.name == param.name }) {
                    paramType = MIRType.from(memberSym.type)
                } else {
                    paramType = .unit
                }
                fields.append((param.name, paramType))
            }
        }

        // Gather member fields and methods
        for member in c.members {
            switch member {
            case .property(let p):
                let propType: MIRType
                if let info = result.symbolTable.lookupType(c.name),
                   let memberSym = info.members.first(where: { $0.name == p.name }) {
                    propType = MIRType.from(memberSym.type)
                } else {
                    propType = .unit
                }
                fields.append((p.name, propType))
            case .function(let f):
                methodNames.append("\(c.name).\(f.name)")
            default:
                break
            }
        }

        typeDecls.append(MIRTypeDecl(name: c.name, fields: fields, methods: methodNames))

        // Lower member methods
        let savedClassName = currentClassName
        currentClassName = c.name
        for member in c.members {
            if case .function(let f) = member {
                lowerFunction(f)
            }
        }
        currentClassName = savedClassName
    }

    // MARK: - Interface Lowering

    private func lowerInterface(_ i: InterfaceDecl) {
        var methodNames: [String] = []
        for member in i.members {
            if case .function(let f) = member {
                methodNames.append("\(i.name).\(f.name)")
            }
        }
        typeDecls.append(MIRTypeDecl(name: i.name, methods: methodNames))
    }

    // MARK: - Enum Lowering

    private func lowerEnum(_ e: EnumClassDecl) {
        // Enum type has a single $variant field storing the entry name
        let fields: [(String, MIRType)] = [("$variant", .string)]
        var methodNames: [String] = []
        for member in e.members {
            if case .function(let f) = member {
                methodNames.append("\(e.name).\(f.name)")
            }
        }
        typeDecls.append(MIRTypeDecl(name: e.name, fields: fields, methods: methodNames))

        // Create a global singleton for each enum entry
        for entry in e.entries {
            let globalName = "\(e.name).\(entry.name)"
            let initName = "__init_\(e.name)_\(entry.name)"

            // Create initializer function: allocates an object with $variant = "entryName"
            let savedLocals = locals
            locals = [:]
            builder.startBlock(label: "entry")

            let variantStr = builder.emitConstString(entry.name)
            let dest = builder.newTemp()
            builder.emit(.newObject(dest: dest, typeName: e.name, args: [variantStr]))
            builder.terminate(.ret(dest))

            let blocks = builder.finishBlocks()
            let mirFunc = MIRFunction(name: initName, parameters: [], returnType: .reference(e.name), blocks: blocks)
            functions.append(mirFunc)
            locals = savedLocals

            globals.append(MIRGlobal(name: globalName, type: .reference(e.name), isMutable: false, initializerFunc: initName))
        }

        // Lower member methods
        let savedClassName = currentClassName
        currentClassName = e.name
        for member in e.members {
            if case .function(let f) = member {
                lowerFunction(f)
            }
        }
        currentClassName = savedClassName
    }

    // MARK: - Object Lowering

    private func lowerObject(_ o: ObjectDecl) {
        var fields: [(String, MIRType)] = []
        var methodNames: [String] = []

        for member in o.members {
            switch member {
            case .property(let p):
                let propType: MIRType
                if let info = result.symbolTable.lookupType(o.name),
                   let memberSym = info.members.first(where: { $0.name == p.name }) {
                    propType = MIRType.from(memberSym.type)
                } else {
                    propType = .unit
                }
                fields.append((p.name, propType))
            case .function(let f):
                methodNames.append("\(o.name).\(f.name)")
            default:
                break
            }
        }

        typeDecls.append(MIRTypeDecl(name: o.name, fields: fields, methods: methodNames))

        // Lower methods
        let savedClassName = currentClassName
        currentClassName = o.name
        for member in o.members {
            if case .function(let f) = member {
                lowerFunction(f)
            }
        }
        currentClassName = savedClassName
    }

    // MARK: - Actor Lowering (as class for Stage 0)

    private func lowerActor(_ a: ActorDecl) {
        var fields: [(String, MIRType)] = []
        var methodNames: [String] = []

        for member in a.members {
            switch member {
            case .property(let p):
                let propType: MIRType
                if let info = result.symbolTable.lookupType(a.name),
                   let memberSym = info.members.first(where: { $0.name == p.name }) {
                    propType = MIRType.from(memberSym.type)
                } else {
                    propType = .unit
                }
                fields.append((p.name, propType))
            case .function(let f):
                methodNames.append("\(a.name).\(f.name)")
            default:
                break
            }
        }

        typeDecls.append(MIRTypeDecl(name: a.name, fields: fields, methods: methodNames))

        let savedClassName = currentClassName
        currentClassName = a.name
        for member in a.members {
            if case .function(let f) = member {
                lowerFunction(f)
            }
        }
        currentClassName = savedClassName
    }

    // MARK: - View / Navigation / Theme (as class for Stage 0)

    private func lowerView(_ v: ViewDecl) {
        typeDecls.append(MIRTypeDecl(name: v.name))
    }

    private func lowerNavigation(_ n: NavigationDecl) {
        typeDecls.append(MIRTypeDecl(name: n.name))
    }

    private func lowerTheme(_ t: ThemeDecl) {
        typeDecls.append(MIRTypeDecl(name: t.name))
    }

    // MARK: - Block & Statement Lowering

    private func lowerBlock(_ block: Block) {
        for stmt in block.statements {
            lowerStatement(stmt)
        }
    }

    private func lowerStatement(_ stmt: Statement) {
        switch stmt {
        case .expression(let expr):
            let _ = lowerExpression(expr)

        case .propertyDecl(let p):
            lowerLocalProperty(p)

        case .returnStmt(let expr, _):
            if let expr = expr {
                let val = lowerExpression(expr)
                builder.terminate(.ret(val))
            } else {
                builder.terminate(.ret(nil))
            }

        case .assignment(let a):
            lowerAssignment(a)

        case .forLoop(let f):
            lowerForLoop(f)

        case .whileLoop(let w):
            lowerWhileLoop(w)

        case .doWhileLoop(let d):
            lowerDoWhileLoop(d)

        case .throwStmt(let expr, _):
            let _ = lowerExpression(expr)
            builder.terminate(.unreachable)

        case .breakStmt:
            if let loop = loopStack.last {
                builder.terminate(.jump(loop.breakLabel))
            }

        case .continueStmt:
            if let loop = loopStack.last {
                builder.terminate(.jump(loop.continueLabel))
            }

        case .declaration(let decl):
            lowerDeclaration(decl)
        }
    }

    // MARK: - Local Property

    private func lowerLocalProperty(_ p: PropertyDecl) {
        let type: MIRType
        if let sym = result.symbolTable.lookup(p.name) {
            type = MIRType.from(sym.type)
        } else {
            type = .unit
        }

        let slot = builder.emitAlloc(type: type)
        locals[p.name] = slot

        if let initializer = p.initializer {
            let val = lowerExpression(initializer)
            builder.emitStore(dest: slot, src: val)
        }
    }

    // MARK: - Assignment

    private func lowerAssignment(_ a: AssignmentStmt) {
        let value = lowerExpression(a.value)

        switch a.op {
        case .assign:
            if case .identifier(let name, _) = a.target {
                if let slot = locals[name] {
                    builder.emitStore(dest: slot, src: value)
                }
            } else if case .memberAccess(let obj, let member, _) = a.target {
                let objTemp = lowerExpression(obj)
                builder.emit(.setField(object: objTemp, fieldName: member, value: value))
            }

        case .plusAssign, .minusAssign, .timesAssign, .divideAssign, .moduloAssign:
            let targetVal: String
            if case .identifier(let name, _) = a.target, let slot = locals[name] {
                targetVal = builder.emitLoad(src: slot)
                let resultTemp = builder.newTemp()
                let opType = lookupExprType(a.target)

                switch a.op {
                case .plusAssign:
                    builder.emit(.add(dest: resultTemp, lhs: targetVal, rhs: value, type: opType))
                case .minusAssign:
                    builder.emit(.sub(dest: resultTemp, lhs: targetVal, rhs: value, type: opType))
                case .timesAssign:
                    builder.emit(.mul(dest: resultTemp, lhs: targetVal, rhs: value, type: opType))
                case .divideAssign:
                    builder.emit(.div(dest: resultTemp, lhs: targetVal, rhs: value, type: opType))
                case .moduloAssign:
                    builder.emit(.mod(dest: resultTemp, lhs: targetVal, rhs: value, type: opType))
                default:
                    break
                }

                builder.emitStore(dest: slot, src: resultTemp)
            } else {
                // Member compound assignment — not fully supported in Stage 0
                let _ = lowerExpression(a.target)
            }
        }
    }

    // MARK: - Control Flow: While

    private func lowerWhileLoop(_ w: WhileLoop) {
        let headerLabel = builder.newBlockLabel("while.header")
        let bodyLabel = builder.newBlockLabel("while.body")
        let exitLabel = builder.newBlockLabel("while.exit")

        loopStack.append((continueLabel: headerLabel, breakLabel: exitLabel))

        builder.terminate(.jump(headerLabel))

        // Header: evaluate condition
        builder.startBlock(label: headerLabel)
        let cond = lowerExpression(w.condition)
        builder.terminate(.branch(condition: cond, thenLabel: bodyLabel, elseLabel: exitLabel))

        // Body
        builder.startBlock(label: bodyLabel)
        lowerBlock(w.body)
        if !builder.isTerminated {
            builder.terminate(.jump(headerLabel))
        }

        loopStack.removeLast()

        // Exit
        builder.startBlock(label: exitLabel)
    }

    // MARK: - Control Flow: Do-While

    private func lowerDoWhileLoop(_ d: DoWhileLoop) {
        let bodyLabel = builder.newBlockLabel("dowhile.body")
        let condLabel = builder.newBlockLabel("dowhile.cond")
        let exitLabel = builder.newBlockLabel("dowhile.exit")

        loopStack.append((continueLabel: condLabel, breakLabel: exitLabel))

        builder.terminate(.jump(bodyLabel))

        // Body
        builder.startBlock(label: bodyLabel)
        lowerBlock(d.body)
        if !builder.isTerminated {
            builder.terminate(.jump(condLabel))
        }

        // Condition
        builder.startBlock(label: condLabel)
        let cond = lowerExpression(d.condition)
        builder.terminate(.branch(condition: cond, thenLabel: bodyLabel, elseLabel: exitLabel))

        loopStack.removeLast()

        // Exit
        builder.startBlock(label: exitLabel)
    }

    // MARK: - Control Flow: For Loop

    private func lowerForLoop(_ f: ForLoop) {
        // Check if iterable is a range expression — emit direct counter loop
        if case .range(let start, let end, let inclusive, _) = f.iterable {
            lowerForLoopRange(variable: f.variable, start: start, end: end, inclusive: inclusive, body: f.body)
            return
        }

        // Collection iteration via iterator protocol (future work)
        let headerLabel = builder.newBlockLabel("for.header")
        let bodyLabel = builder.newBlockLabel("for.body")
        let exitLabel = builder.newBlockLabel("for.exit")

        loopStack.append((continueLabel: headerLabel, breakLabel: exitLabel))

        let iterable = lowerExpression(f.iterable)
        let iterator = builder.newTemp()
        builder.emit(.virtualCall(dest: iterator, object: iterable, method: "iterator", args: []))

        builder.terminate(.jump(headerLabel))

        builder.startBlock(label: headerLabel)
        let hasNext = builder.newTemp()
        builder.emit(.virtualCall(dest: hasNext, object: iterator, method: "hasNext", args: []))
        builder.terminate(.branch(condition: hasNext, thenLabel: bodyLabel, elseLabel: exitLabel))

        builder.startBlock(label: bodyLabel)
        let nextVal = builder.newTemp()
        builder.emit(.virtualCall(dest: nextVal, object: iterator, method: "next", args: []))

        let loopVarSlot = builder.emitAlloc(type: .reference("Any"))
        locals[f.variable] = loopVarSlot
        builder.emitStore(dest: loopVarSlot, src: nextVal)

        lowerBlock(f.body)
        if !builder.isTerminated {
            builder.terminate(.jump(headerLabel))
        }

        loopStack.removeLast()

        builder.startBlock(label: exitLabel)
    }

    /// Lower a for loop over a range as a direct counter loop.
    /// `for (i in start..end)` or `for (i in start..<end)`
    private func lowerForLoopRange(variable: String, start: Expression, end: Expression, inclusive: Bool, body: Block) {
        let headerLabel = builder.newBlockLabel("for.header")
        let bodyLabel = builder.newBlockLabel("for.body")
        let incrLabel = builder.newBlockLabel("for.incr")
        let exitLabel = builder.newBlockLabel("for.exit")

        // continue jumps to increment (not header) so counter advances
        loopStack.append((continueLabel: incrLabel, breakLabel: exitLabel))

        // Lower start and end expressions
        let startTemp = lowerExpression(start)
        let endTemp = lowerExpression(end)

        // Alloc loop variable and initialize to start
        let loopVarSlot = builder.emitAlloc(type: .int)
        locals[variable] = loopVarSlot
        builder.emitStore(dest: loopVarSlot, src: startTemp)

        builder.terminate(.jump(headerLabel))

        // Header: load loop var, compare with end
        builder.startBlock(label: headerLabel)
        let current = builder.emitLoad(src: loopVarSlot)
        let cond = builder.newTemp()
        if inclusive {
            builder.emit(.lte(dest: cond, lhs: current, rhs: endTemp, type: .int))
        } else {
            builder.emit(.lt(dest: cond, lhs: current, rhs: endTemp, type: .int))
        }
        builder.terminate(.branch(condition: cond, thenLabel: bodyLabel, elseLabel: exitLabel))

        // Body
        builder.startBlock(label: bodyLabel)
        lowerBlock(body)
        if !builder.isTerminated {
            builder.terminate(.jump(incrLabel))
        }

        // Increment: load current, add 1, store back, jump to header
        builder.startBlock(label: incrLabel)
        let cur = builder.emitLoad(src: loopVarSlot)
        let one = builder.emitConstInt(1)
        let next = builder.newTemp()
        builder.emit(.add(dest: next, lhs: cur, rhs: one, type: .int))
        builder.emitStore(dest: loopVarSlot, src: next)
        builder.terminate(.jump(headerLabel))

        loopStack.removeLast()

        // Exit
        builder.startBlock(label: exitLabel)
    }

    // MARK: - Expression Lowering

    /// Lower an expression, returning the temp holding the result.
    @discardableResult
    private func lowerExpression(_ expr: Expression) -> String {
        switch expr {
        // Literals
        case .intLiteral(let value, _):
            return builder.emitConstInt(value)

        case .floatLiteral(let value, _):
            return builder.emitConstFloat(value)

        case .stringLiteral(let value, _):
            return builder.emitConstString(value)

        case .boolLiteral(let value, _):
            return builder.emitConstBool(value)

        case .nullLiteral:
            return builder.emitConstNull()

        case .interpolatedString(let parts, _):
            return lowerInterpolatedString(parts)

        // References
        case .identifier(let name, _):
            if let slot = locals[name] {
                return builder.emitLoad(src: slot)
            }
            // Global or unresolved — emit a load from the name directly
            return builder.emitLoad(src: "global.\(name)")

        case .this:
            return builder.emitLoad(src: "this")

        case .super:
            return builder.emitLoad(src: "super")

        // Binary operators
        case .binary(let left, let op, let right, _):
            return lowerBinary(left: left, op: op, right: right)

        // Unary prefix
        case .unaryPrefix(let op, let operand, _):
            return lowerUnaryPrefix(op: op, operand: operand)

        // Unary postfix
        case .unaryPostfix(let operand, let op, _):
            return lowerUnaryPostfix(operand: operand, op: op)

        // Member access
        case .memberAccess(let obj, let member, _):
            // Check if this is an enum entry reference (e.g., Color.RED)
            if case .identifier(let typeName, _) = obj,
               let typeInfo = result.symbolTable.lookupType(typeName),
               !typeInfo.enumEntries.isEmpty,
               typeInfo.enumEntries.contains(member) {
                // Enum entry — load from the global singleton
                return builder.emitLoad(src: "global.\(typeName).\(member)")
            }
            let objTemp = lowerExpression(obj)
            let dest = builder.newTemp()
            builder.emit(.getField(dest: dest, object: objTemp, fieldName: member))
            return dest

        case .nullSafeMemberAccess(let obj, let member, _):
            return lowerNullSafeMemberAccess(object: obj, member: member)

        // Subscript
        case .subscriptAccess(let obj, let index, _):
            let objTemp = lowerExpression(obj)
            let idxTemp = lowerExpression(index)
            let dest = builder.newTemp()
            builder.emit(.virtualCall(dest: dest, object: objTemp, method: "get", args: [idxTemp]))
            return dest

        // Call
        case .call(let callee, let args, let trailing, _):
            return lowerCall(callee: callee, arguments: args, trailingLambda: trailing)

        // If expression
        case .ifExpr(let ie):
            return lowerIfExpr(ie)

        // When expression
        case .whenExpr(let we):
            return lowerWhenExpr(we)

        // Lambda
        case .lambda(let le):
            return lowerLambda(le)

        // Type operations
        case .typeCheck(let expr, let typeNode, _):
            return lowerTypeCheck(expr: expr, typeNode: typeNode)

        case .typeCast(let expr, let typeNode, _):
            return lowerTypeCast(expr: expr, typeNode: typeNode)

        case .safeCast(let expr, let typeNode, _):
            return lowerSafeCast(expr: expr, typeNode: typeNode)

        case .nonNullAssert(let expr, _):
            return lowerNonNullAssert(expr: expr)

        // Elvis
        case .elvis(let left, let right, _):
            return lowerElvis(left: left, right: right)

        // Range
        case .range(let start, let end, let inclusive, _):
            return lowerRange(start: start, end: end, inclusive: inclusive)

        // Parenthesized
        case .parenthesized(let inner, _):
            return lowerExpression(inner)

        // Error
        case .error:
            return builder.emitConstNull()
        }
    }

    // MARK: - Binary Operations

    private func lowerBinary(left: Expression, op: BinaryOp, right: Expression) -> String {
        let lhs = lowerExpression(left)
        let rhs = lowerExpression(right)
        let dest = builder.newTemp()
        let type = lookupExprType(left)

        switch op {
        case .plus:     builder.emit(.add(dest: dest, lhs: lhs, rhs: rhs, type: type))
        case .minus:    builder.emit(.sub(dest: dest, lhs: lhs, rhs: rhs, type: type))
        case .times:    builder.emit(.mul(dest: dest, lhs: lhs, rhs: rhs, type: type))
        case .divide:   builder.emit(.div(dest: dest, lhs: lhs, rhs: rhs, type: type))
        case .modulo:   builder.emit(.mod(dest: dest, lhs: lhs, rhs: rhs, type: type))

        case .equalEqual:   builder.emit(.eq(dest: dest, lhs: lhs, rhs: rhs, type: type))
        case .notEqual:     builder.emit(.neq(dest: dest, lhs: lhs, rhs: rhs, type: type))
        case .less:         builder.emit(.lt(dest: dest, lhs: lhs, rhs: rhs, type: type))
        case .lessEqual:    builder.emit(.lte(dest: dest, lhs: lhs, rhs: rhs, type: type))
        case .greater:      builder.emit(.gt(dest: dest, lhs: lhs, rhs: rhs, type: type))
        case .greaterEqual: builder.emit(.gte(dest: dest, lhs: lhs, rhs: rhs, type: type))

        case .and:  builder.emit(.and(dest: dest, lhs: lhs, rhs: rhs))
        case .or:   builder.emit(.or(dest: dest, lhs: lhs, rhs: rhs))
        }

        return dest
    }

    // MARK: - Unary Operations

    private func lowerUnaryPrefix(op: UnaryOp, operand: Expression) -> String {
        let operandTemp = lowerExpression(operand)
        let dest = builder.newTemp()
        let type = lookupExprType(operand)

        switch op {
        case .negate:
            builder.emit(.neg(dest: dest, operand: operandTemp, type: type))
        case .not:
            builder.emit(.not(dest: dest, operand: operandTemp))
        }

        return dest
    }

    private func lowerUnaryPostfix(operand: Expression, op: PostfixOp) -> String {
        switch op {
        case .nonNullAssert:
            return lowerNonNullAssert(expr: operand)
        }
    }

    // MARK: - String Interpolation

    private func lowerInterpolatedString(_ parts: [StringPart]) -> String {
        var partTemps: [String] = []
        for part in parts {
            switch part {
            case .literal(let s):
                partTemps.append(builder.emitConstString(s))
            case .interpolation(let expr):
                partTemps.append(lowerExpression(expr))
            }
        }
        let dest = builder.newTemp()
        builder.emit(.stringConcat(dest: dest, parts: partTemps))
        return dest
    }

    // MARK: - Call Lowering

    private func lowerCall(callee: Expression, arguments: [CallArgument], trailingLambda: LambdaExpr?) -> String {
        let argTemps = arguments.map { lowerExpression($0.value) }

        // Handle method calls: callee is memberAccess
        if case .memberAccess(let obj, let method, _) = callee {
            let objTemp = lowerExpression(obj)
            let dest = builder.newTemp()
            builder.emit(.virtualCall(dest: dest, object: objTemp, method: method, args: argTemps))
            return dest
        }

        // Handle null-safe method calls
        if case .nullSafeMemberAccess(let obj, let method, _) = callee {
            let objTemp = lowerExpression(obj)
            // Null-safe call: check null, branch
            let isNullTemp = builder.newTemp()
            builder.emit(.isNull(dest: isNullTemp, operand: objTemp))

            let nonNullLabel = builder.newBlockLabel("safecall.nonnull")
            let nullLabel = builder.newBlockLabel("safecall.null")
            let mergeLabel = builder.newBlockLabel("safecall.merge")

            let resultSlot = builder.emitAlloc(type: .nullable(.unit))

            builder.terminate(.branch(condition: isNullTemp, thenLabel: nullLabel, elseLabel: nonNullLabel))

            // Non-null path: do the call
            builder.startBlock(label: nonNullLabel)
            let callResult = builder.newTemp()
            builder.emit(.virtualCall(dest: callResult, object: objTemp, method: method, args: argTemps))
            builder.emitStore(dest: resultSlot, src: callResult)
            builder.terminate(.jump(mergeLabel))

            // Null path: store null
            builder.startBlock(label: nullLabel)
            let nullVal = builder.emitConstNull()
            builder.emitStore(dest: resultSlot, src: nullVal)
            builder.terminate(.jump(mergeLabel))

            // Merge
            builder.startBlock(label: mergeLabel)
            return builder.emitLoad(src: resultSlot)
        }

        // Simple function call
        if case .identifier(let name, _) = callee {
            // Check if it's a constructor call (type declaration)
            if let sym = result.symbolTable.lookup(name), sym.kind == .typeDeclaration {
                let dest = builder.newTemp()
                builder.emit(.newObject(dest: dest, typeName: name, args: argTemps))
                return dest
            }

            // Check if it's a local variable holding a function reference
            if locals[name] != nil {
                let calleeTemp = lowerExpression(callee)
                let dest = builder.newTemp()
                builder.emit(.callIndirect(dest: dest, functionRef: calleeTemp, args: argTemps))
                return dest
            }

            // Regular function call
            let dest = builder.newTemp()
            builder.emit(.call(dest: dest, function: name, args: argTemps))
            return dest
        }

        // Fallback: indirect call (e.g. calling a lambda stored in a variable)
        let calleeTemp = lowerExpression(callee)
        let dest = builder.newTemp()
        builder.emit(.callIndirect(dest: dest, functionRef: calleeTemp, args: argTemps))
        return dest
    }

    // MARK: - If Expression

    private func lowerIfExpr(_ ie: IfExpr) -> String {
        let cond = lowerExpression(ie.condition)

        let thenLabel = builder.newBlockLabel("if.then")
        let elseLabel = builder.newBlockLabel("if.else")
        let mergeLabel = builder.newBlockLabel("if.merge")

        let resultSlot = builder.emitAlloc(type: .unit)

        builder.terminate(.branch(condition: cond, thenLabel: thenLabel, elseLabel: elseLabel))

        // Then branch
        builder.startBlock(label: thenLabel)
        lowerBlock(ie.thenBranch)
        if !builder.isTerminated {
            builder.terminate(.jump(mergeLabel))
        }

        // Else branch
        builder.startBlock(label: elseLabel)
        if let elseBranch = ie.elseBranch {
            switch elseBranch {
            case .elseBlock(let block):
                lowerBlock(block)
            case .elseIf(let elseIf):
                let _ = lowerIfExpr(elseIf)
            }
        }
        if !builder.isTerminated {
            builder.terminate(.jump(mergeLabel))
        }

        // Merge
        builder.startBlock(label: mergeLabel)
        return builder.emitLoad(src: resultSlot)
    }

    // MARK: - When Expression

    private func lowerWhenExpr(_ we: WhenExpr) -> String {
        let subject: String?
        if let subjectExpr = we.subject {
            subject = lowerExpression(subjectExpr)
        } else {
            subject = nil
        }

        let mergeLabel = builder.newBlockLabel("when.merge")
        let resultSlot = builder.emitAlloc(type: .unit)

        for (index, entry) in we.entries.enumerated() {
            let bodyLabel = builder.newBlockLabel("when.body\(index)")
            let nextLabel: String
            if index + 1 < we.entries.count {
                nextLabel = builder.newBlockLabel("when.check\(index + 1)")
            } else {
                nextLabel = mergeLabel
            }

            // Evaluate condition
            var isElse = false
            for condition in entry.conditions {
                switch condition {
                case .expression(let expr):
                    if case .identifier(let name, _) = expr, name == "else" {
                        isElse = true
                    } else if let subj = subject {
                        let condVal = lowerExpression(expr)
                        let cmpTemp = builder.newTemp()
                        builder.emit(.eq(dest: cmpTemp, lhs: subj, rhs: condVal, type: .unit))
                        builder.terminate(.branch(condition: cmpTemp, thenLabel: bodyLabel, elseLabel: nextLabel))
                    } else {
                        let condVal = lowerExpression(expr)
                        builder.terminate(.branch(condition: condVal, thenLabel: bodyLabel, elseLabel: nextLabel))
                    }
                case .isType(_, _):
                    if let subj = subject {
                        let checkTemp = builder.newTemp()
                        let typeName = typeNodeName(condition)
                        builder.emit(.typeCheck(dest: checkTemp, operand: subj, typeName: typeName))
                        builder.terminate(.branch(condition: checkTemp, thenLabel: bodyLabel, elseLabel: nextLabel))
                    }
                }
            }

            if isElse {
                builder.terminate(.jump(bodyLabel))
            }

            // Body
            builder.startBlock(label: bodyLabel)
            switch entry.body {
            case .expression(let expr):
                let val = lowerExpression(expr)
                builder.emitStore(dest: resultSlot, src: val)
            case .block(let block):
                lowerBlock(block)
            }
            if !builder.isTerminated {
                builder.terminate(.jump(mergeLabel))
            }

            // Next check block (if not last)
            if index + 1 < we.entries.count {
                builder.startBlock(label: nextLabel)
            }
        }

        // Merge
        builder.startBlock(label: mergeLabel)
        return builder.emitLoad(src: resultSlot)
    }

    // MARK: - Lambda

    private func lowerLambda(_ le: LambdaExpr) -> String {
        // Stage 0: lower as an anonymous function, return a reference to it
        // Use a separate builder to avoid corrupting the outer function's blocks
        let lambdaBuilder = MIRBuilder()
        let lambdaName = "__lambda_\(lambdaBuilder.newTemp().dropFirst())"

        let savedLocals = locals
        let savedBuilder = builder
        locals = [:]
        builder = lambdaBuilder

        let params: [(String, MIRType)] = le.parameters.map { p in
            let type: MIRType = p.type.flatMap { _ in
                if let sym = result.symbolTable.lookup(p.name) {
                    return MIRType.from(sym.type)
                }
                return nil
            } ?? .unit
            return (p.name, type)
        }

        builder.startBlock(label: "entry")
        for (name, type) in params {
            let slot = builder.emitAlloc(type: type)
            locals[name] = slot
            // Load parameter value and store into slot (same pattern as lowerFunction)
            let paramTemp = builder.newTemp()
            builder.emit(.load(dest: paramTemp, src: "param.\(name)"))
            builder.emitStore(dest: slot, src: paramTemp)
        }

        // Lower all statements except the last
        if le.body.count > 1 {
            for stmt in le.body.dropLast() {
                lowerStatement(stmt)
            }
        }

        // If the last statement is an expression, return its value
        if !builder.isTerminated, let lastStmt = le.body.last {
            if case .expression(let expr) = lastStmt {
                let resultTemp = lowerExpression(expr)
                builder.terminate(.ret(resultTemp))
            } else {
                lowerStatement(lastStmt)
                if !builder.isTerminated {
                    builder.terminate(.ret(nil))
                }
            }
        } else if !builder.isTerminated {
            builder.terminate(.ret(nil))
        }

        let blocks = builder.finishBlocks()
        let mirFunc = MIRFunction(name: lambdaName, parameters: params, returnType: .unit, blocks: blocks)
        functions.append(mirFunc)

        // Restore outer function's builder and locals
        builder = savedBuilder
        locals = savedLocals

        // Return a reference to the lambda function name
        return builder.emitConstString(lambdaName)
    }

    // MARK: - Null Safety

    private func lowerNullSafeMemberAccess(object: Expression, member: String) -> String {
        let objTemp = lowerExpression(object)
        let isNullTemp = builder.newTemp()
        builder.emit(.isNull(dest: isNullTemp, operand: objTemp))

        let nonNullLabel = builder.newBlockLabel("safe.nonnull")
        let nullLabel = builder.newBlockLabel("safe.null")
        let mergeLabel = builder.newBlockLabel("safe.merge")

        let resultSlot = builder.emitAlloc(type: .nullable(.unit))

        builder.terminate(.branch(condition: isNullTemp, thenLabel: nullLabel, elseLabel: nonNullLabel))

        // Non-null path
        builder.startBlock(label: nonNullLabel)
        let fieldVal = builder.newTemp()
        builder.emit(.getField(dest: fieldVal, object: objTemp, fieldName: member))
        builder.emitStore(dest: resultSlot, src: fieldVal)
        builder.terminate(.jump(mergeLabel))

        // Null path
        builder.startBlock(label: nullLabel)
        let nullVal = builder.emitConstNull()
        builder.emitStore(dest: resultSlot, src: nullVal)
        builder.terminate(.jump(mergeLabel))

        // Merge
        builder.startBlock(label: mergeLabel)
        return builder.emitLoad(src: resultSlot)
    }

    private func lowerNonNullAssert(expr: Expression) -> String {
        let operandTemp = lowerExpression(expr)
        let dest = builder.newTemp()
        builder.emit(.nullCheck(dest: dest, operand: operandTemp))
        return dest
    }

    private func lowerElvis(left: Expression, right: Expression) -> String {
        let leftVal = lowerExpression(left)
        let isNullTemp = builder.newTemp()
        builder.emit(.isNull(dest: isNullTemp, operand: leftVal))

        let nonNullLabel = builder.newBlockLabel("elvis.nonnull")
        let nullLabel = builder.newBlockLabel("elvis.null")
        let mergeLabel = builder.newBlockLabel("elvis.merge")

        let resultSlot = builder.emitAlloc(type: .unit)

        builder.terminate(.branch(condition: isNullTemp, thenLabel: nullLabel, elseLabel: nonNullLabel))

        // Non-null: use left value
        builder.startBlock(label: nonNullLabel)
        builder.emitStore(dest: resultSlot, src: leftVal)
        builder.terminate(.jump(mergeLabel))

        // Null: evaluate right
        builder.startBlock(label: nullLabel)
        let rightVal = lowerExpression(right)
        builder.emitStore(dest: resultSlot, src: rightVal)
        builder.terminate(.jump(mergeLabel))

        // Merge
        builder.startBlock(label: mergeLabel)
        return builder.emitLoad(src: resultSlot)
    }

    // MARK: - Type Operations

    private func lowerTypeCheck(expr: Expression, typeNode: TypeNode) -> String {
        let operandTemp = lowerExpression(expr)
        let dest = builder.newTemp()
        let typeName = typeNodeSimpleName(typeNode)
        builder.emit(.typeCheck(dest: dest, operand: operandTemp, typeName: typeName))
        return dest
    }

    private func lowerTypeCast(expr: Expression, typeNode: TypeNode) -> String {
        let operandTemp = lowerExpression(expr)
        let dest = builder.newTemp()
        let typeName = typeNodeSimpleName(typeNode)
        builder.emit(.typeCast(dest: dest, operand: operandTemp, typeName: typeName))
        return dest
    }

    private func lowerSafeCast(expr: Expression, typeNode: TypeNode) -> String {
        let operandTemp = lowerExpression(expr)
        let typeName = typeNodeSimpleName(typeNode)

        // Check type, branch on result
        let checkTemp = builder.newTemp()
        builder.emit(.typeCheck(dest: checkTemp, operand: operandTemp, typeName: typeName))

        let castLabel = builder.newBlockLabel("safecast.ok")
        let nullLabel = builder.newBlockLabel("safecast.null")
        let mergeLabel = builder.newBlockLabel("safecast.merge")

        let resultSlot = builder.emitAlloc(type: .nullable(.unit))

        builder.terminate(.branch(condition: checkTemp, thenLabel: castLabel, elseLabel: nullLabel))

        // Cast succeeds
        builder.startBlock(label: castLabel)
        let castTemp = builder.newTemp()
        builder.emit(.typeCast(dest: castTemp, operand: operandTemp, typeName: typeName))
        builder.emitStore(dest: resultSlot, src: castTemp)
        builder.terminate(.jump(mergeLabel))

        // Cast fails — store null
        builder.startBlock(label: nullLabel)
        let nullVal = builder.emitConstNull()
        builder.emitStore(dest: resultSlot, src: nullVal)
        builder.terminate(.jump(mergeLabel))

        // Merge
        builder.startBlock(label: mergeLabel)
        return builder.emitLoad(src: resultSlot)
    }

    // MARK: - Range

    private func lowerRange(start: Expression, end: Expression, inclusive: Bool) -> String {
        let startTemp = lowerExpression(start)
        let endTemp = lowerExpression(end)
        let rangeName = inclusive ? "rangeTo" : "rangeUntil"
        let dest = builder.newTemp()
        builder.emit(.call(dest: dest, function: rangeName, args: [startTemp, endTemp]))
        return dest
    }

    // MARK: - Helpers

    /// Look up the MIR type for an expression using the type map.
    private func lookupExprType(_ expr: Expression) -> MIRType {
        let id = ExpressionID(expr.span)
        if let type = result.typeMap[id] {
            return MIRType.from(type)
        }
        return .unit
    }

    /// Extract a simple name from a TypeNode.
    private func typeNodeSimpleName(_ node: TypeNode) -> String {
        switch node {
        case .simple(let name, _, _):
            return name
        case .nullable(let inner, _):
            return typeNodeSimpleName(inner) + "?"
        case .qualified(_, let member, _):
            return member
        default:
            return "Any"
        }
    }

    /// Extract a type name from a WhenCondition.
    private func typeNodeName(_ condition: WhenCondition) -> String {
        switch condition {
        case .isType(let typeNode, _):
            return typeNodeSimpleName(typeNode)
        case .expression:
            return "Any"
        }
    }
}
