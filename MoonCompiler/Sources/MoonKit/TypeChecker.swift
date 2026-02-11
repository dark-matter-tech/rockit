// TypeChecker.swift
// MoonKit — Moon Language Compiler
// Copyright © 2026 Dark Matter Tech. All rights reserved.

// MARK: - Type Check Result

/// The output of the type checker
public struct TypeCheckResult {
    public let ast: SourceFile
    public let typeMap: [ExpressionID: Type]
    public let symbolTable: SymbolTable
    public let diagnostics: DiagnosticEngine
}

// MARK: - Type Checker

/// Two-pass type checker for Moon.
///
/// **Pass 1** gathers all declarations (functions, properties, classes, etc.)
/// into the symbol table so that forward references work.
///
/// **Pass 2** walks expression trees, infers/checks types, enforces null safety,
/// and checks sealed-class exhaustiveness in `when` expressions.
public final class TypeChecker {
    private let ast: SourceFile
    private let diagnostics: DiagnosticEngine
    private let symbolTable: SymbolTable
    private let resolver: TypeResolver
    private var typeMap: [ExpressionID: Type] = [:]

    public init(ast: SourceFile, diagnostics: DiagnosticEngine) {
        self.ast = ast
        self.diagnostics = diagnostics
        self.symbolTable = SymbolTable()
        self.resolver = TypeResolver(symbolTable: symbolTable, diagnostics: diagnostics)
    }

    /// Run both passes and return the result.
    public func check() -> TypeCheckResult {
        // Pass 1: gather declarations
        for decl in ast.declarations {
            gatherDeclaration(decl)
        }

        // Pass 2: check bodies and expressions
        for decl in ast.declarations {
            checkDeclaration(decl)
        }

        return TypeCheckResult(
            ast: ast,
            typeMap: typeMap,
            symbolTable: symbolTable,
            diagnostics: diagnostics
        )
    }

    // MARK: - Pass 1: Declaration Gathering

    private func gatherDeclaration(_ decl: Declaration) {
        switch decl {
        case .function(let f):
            gatherFunction(f)
        case .property(let p):
            gatherProperty(p)
        case .classDecl(let c):
            gatherClass(c)
        case .interfaceDecl(let i):
            gatherInterface(i)
        case .enumDecl(let e):
            gatherEnum(e)
        case .objectDecl(let o):
            gatherObject(o)
        case .actorDecl(let a):
            gatherActor(a)
        case .viewDecl(let v):
            gatherView(v)
        case .navigationDecl(let n):
            gatherNavigation(n)
        case .themeDecl(let t):
            gatherTheme(t)
        case .typeAlias(let ta):
            gatherTypeAlias(ta)
        }
    }

    private func gatherFunction(_ f: FunctionDecl) {
        let paramTypes = f.parameters.map { param -> Type in
            if let typeNode = param.type {
                return resolver.resolve(typeNode)
            }
            return .error
        }
        let returnType: Type
        if let retNode = f.returnType {
            returnType = resolver.resolve(retNode)
        } else {
            returnType = .unit
        }
        let funcType = Type.function(parameterTypes: paramTypes, returnType: returnType)
        let symbol = Symbol(name: f.name, type: funcType, kind: .function, span: f.span)
        if !symbolTable.define(symbol) {
            diagnostics.error("redeclaration of '\(f.name)'", at: f.span.start)
        }
    }

    private func gatherProperty(_ p: PropertyDecl) {
        let type: Type
        if let typeNode = p.type {
            type = resolver.resolve(typeNode)
        } else if p.initializer != nil {
            // Type will be inferred in pass 2
            type = .error
        } else {
            diagnostics.error("property '\(p.name)' must have a type annotation or initializer", at: p.span.start)
            type = .error
        }
        let isMutable = !p.isVal
        let symbol = Symbol(name: p.name, type: type, kind: .variable(isMutable: isMutable), span: p.span)
        if !symbolTable.define(symbol) {
            diagnostics.error("redeclaration of '\(p.name)'", at: p.span.start)
        }
    }

    private func gatherClass(_ c: ClassDecl) {
        // Register the class as a type declaration
        let typeParamNames = c.typeParameters.map { $0.name }
        let superTypeNames = c.superTypes.compactMap { superType -> String? in
            if case .simple(let name, _, _) = superType { return name }
            return nil
        }

        var info = TypeDeclInfo(
            name: c.name,
            typeParameters: typeParamNames,
            superTypes: superTypeNames
        )

        // Register type parameters in a new scope for the class body
        symbolTable.pushScope()
        for tp in c.typeParameters {
            let bound: Type? = tp.upperBound.map { resolver.resolve($0) }
            let tpType = Type.typeParameter(name: tp.name, bound: bound)
            symbolTable.define(Symbol(name: tp.name, type: tpType, kind: .typeParameter, span: tp.span))
        }

        // Gather constructor parameters as members
        for param in c.constructorParams {
            if param.isVal || param.isVar {
                let paramType: Type
                if let typeNode = param.type {
                    paramType = resolver.resolve(typeNode)
                } else {
                    paramType = .error
                }
                let memberSymbol = Symbol(
                    name: param.name,
                    type: paramType,
                    kind: .variable(isMutable: param.isVar),
                    span: param.span
                )
                info.members.append(memberSymbol)
            }
        }

        // Gather members
        for member in c.members {
            gatherDeclaration(member)
            if case .function(let f) = member {
                let paramTypes = f.parameters.map { p -> Type in
                    p.type.map { resolver.resolve($0) } ?? .error
                }
                let retType = f.returnType.map { resolver.resolve($0) } ?? .unit
                let memberSym = Symbol(
                    name: f.name,
                    type: .function(parameterTypes: paramTypes, returnType: retType),
                    kind: .function,
                    span: f.span
                )
                info.members.append(memberSym)
            } else if case .property(let p) = member {
                let propType = p.type.map { resolver.resolve($0) } ?? .error
                let memberSym = Symbol(
                    name: p.name,
                    type: propType,
                    kind: .variable(isMutable: !p.isVal),
                    span: p.span
                )
                info.members.append(memberSym)
            }
        }

        symbolTable.popScope()

        symbolTable.registerType(info)

        // Track sealed subclasses
        if c.modifiers.contains(.sealed) {
            // Sealed class registered — subclasses will register themselves
        }

        // If this class has a sealed parent, register as subclass
        for superName in superTypeNames {
            if let parentInfo = symbolTable.lookupType(superName),
               !parentInfo.sealedSubclasses.isEmpty || true {
                // We don't know if parent is sealed at gather time (forward ref),
                // so we always try. The TypeDeclInfo will just accumulate subclass names.
                symbolTable.addSealedSubclass(parent: superName, child: c.name)
            }
        }

        // Register class symbol
        let classType = Type.classType(name: c.name, typeArguments: [])
        let symbol = Symbol(name: c.name, type: classType, kind: .typeDeclaration, span: c.span)
        if !symbolTable.define(symbol) {
            diagnostics.error("redeclaration of type '\(c.name)'", at: c.span.start)
        }
    }

    private func gatherInterface(_ i: InterfaceDecl) {
        let typeParamNames = i.typeParameters.map { $0.name }
        let superTypeNames = i.superTypes.compactMap { st -> String? in
            if case .simple(let name, _, _) = st { return name }
            return nil
        }

        var info = TypeDeclInfo(
            name: i.name,
            typeParameters: typeParamNames,
            superTypes: superTypeNames
        )

        symbolTable.pushScope()
        for tp in i.typeParameters {
            let bound: Type? = tp.upperBound.map { resolver.resolve($0) }
            let tpType = Type.typeParameter(name: tp.name, bound: bound)
            symbolTable.define(Symbol(name: tp.name, type: tpType, kind: .typeParameter, span: tp.span))
        }

        for member in i.members {
            gatherDeclaration(member)
            if case .function(let f) = member {
                let paramTypes = f.parameters.map { p -> Type in
                    p.type.map { resolver.resolve($0) } ?? .error
                }
                let retType = f.returnType.map { resolver.resolve($0) } ?? .unit
                info.members.append(Symbol(
                    name: f.name,
                    type: .function(parameterTypes: paramTypes, returnType: retType),
                    kind: .function,
                    span: f.span
                ))
            } else if case .property(let p) = member {
                let propType = p.type.map { resolver.resolve($0) } ?? .error
                info.members.append(Symbol(
                    name: p.name,
                    type: propType,
                    kind: .variable(isMutable: !p.isVal),
                    span: p.span
                ))
            }
        }

        symbolTable.popScope()
        symbolTable.registerType(info)

        let ifaceType = Type.interfaceType(name: i.name, typeArguments: [])
        let symbol = Symbol(name: i.name, type: ifaceType, kind: .typeDeclaration, span: i.span)
        if !symbolTable.define(symbol) {
            diagnostics.error("redeclaration of type '\(i.name)'", at: i.span.start)
        }
    }

    private func gatherEnum(_ e: EnumClassDecl) {
        let entryNames = e.entries.map { $0.name }
        var info = TypeDeclInfo(
            name: e.name,
            typeParameters: e.typeParameters.map { $0.name },
            enumEntries: entryNames
        )

        // Gather members
        for member in e.members {
            gatherDeclaration(member)
            if case .function(let f) = member {
                let paramTypes = f.parameters.map { p -> Type in
                    p.type.map { resolver.resolve($0) } ?? .error
                }
                let retType = f.returnType.map { resolver.resolve($0) } ?? .unit
                info.members.append(Symbol(
                    name: f.name,
                    type: .function(parameterTypes: paramTypes, returnType: retType),
                    kind: .function,
                    span: f.span
                ))
            }
        }

        symbolTable.registerType(info)

        // Register enum entries as symbols
        let enumType = Type.enumType(name: e.name)
        for entry in e.entries {
            symbolTable.define(Symbol(name: entry.name, type: enumType, kind: .enumEntry, span: entry.span))
        }

        let symbol = Symbol(name: e.name, type: enumType, kind: .typeDeclaration, span: e.span)
        if !symbolTable.define(symbol) {
            diagnostics.error("redeclaration of type '\(e.name)'", at: e.span.start)
        }
    }

    private func gatherObject(_ o: ObjectDecl) {
        var info = TypeDeclInfo(name: o.name)
        for member in o.members {
            gatherDeclaration(member)
            if case .property(let p) = member {
                let propType = p.type.map { resolver.resolve($0) } ?? .error
                info.members.append(Symbol(
                    name: p.name, type: propType,
                    kind: .variable(isMutable: !p.isVal), span: p.span
                ))
            } else if case .function(let f) = member {
                let paramTypes = f.parameters.map { p -> Type in
                    p.type.map { resolver.resolve($0) } ?? .error
                }
                let retType = f.returnType.map { resolver.resolve($0) } ?? .unit
                info.members.append(Symbol(
                    name: f.name,
                    type: .function(parameterTypes: paramTypes, returnType: retType),
                    kind: .function, span: f.span
                ))
            }
        }
        symbolTable.registerType(info)

        let objType = Type.objectType(name: o.name)
        let symbol = Symbol(name: o.name, type: objType, kind: .typeDeclaration, span: o.span)
        if !symbolTable.define(symbol) {
            diagnostics.error("redeclaration of type '\(o.name)'", at: o.span.start)
        }
    }

    private func gatherActor(_ a: ActorDecl) {
        var info = TypeDeclInfo(name: a.name)
        for member in a.members {
            gatherDeclaration(member)
            if case .property(let p) = member {
                let propType = p.type.map { resolver.resolve($0) } ?? .error
                info.members.append(Symbol(
                    name: p.name, type: propType,
                    kind: .variable(isMutable: !p.isVal), span: p.span
                ))
            } else if case .function(let f) = member {
                let paramTypes = f.parameters.map { p -> Type in
                    p.type.map { resolver.resolve($0) } ?? .error
                }
                let retType = f.returnType.map { resolver.resolve($0) } ?? .unit
                info.members.append(Symbol(
                    name: f.name,
                    type: .function(parameterTypes: paramTypes, returnType: retType),
                    kind: .function, span: f.span
                ))
            }
        }
        symbolTable.registerType(info)

        let actorType = Type.actorType(name: a.name)
        let symbol = Symbol(name: a.name, type: actorType, kind: .typeDeclaration, span: a.span)
        if !symbolTable.define(symbol) {
            diagnostics.error("redeclaration of type '\(a.name)'", at: a.span.start)
        }
    }

    private func gatherView(_ v: ViewDecl) {
        // Views are registered as type declarations with loose typing
        let info = TypeDeclInfo(name: v.name)
        symbolTable.registerType(info)

        let viewType = Type.classType(name: v.name, typeArguments: [])
        let symbol = Symbol(name: v.name, type: viewType, kind: .typeDeclaration, span: v.span)
        if !symbolTable.define(symbol) {
            diagnostics.error("redeclaration of '\(v.name)'", at: v.span.start)
        }
    }

    private func gatherNavigation(_ n: NavigationDecl) {
        let info = TypeDeclInfo(name: n.name)
        symbolTable.registerType(info)

        let navType = Type.classType(name: n.name, typeArguments: [])
        let symbol = Symbol(name: n.name, type: navType, kind: .typeDeclaration, span: n.span)
        if !symbolTable.define(symbol) {
            diagnostics.error("redeclaration of '\(n.name)'", at: n.span.start)
        }
    }

    private func gatherTheme(_ t: ThemeDecl) {
        let info = TypeDeclInfo(name: t.name)
        symbolTable.registerType(info)

        let themeType = Type.classType(name: t.name, typeArguments: [])
        let symbol = Symbol(name: t.name, type: themeType, kind: .typeDeclaration, span: t.span)
        if !symbolTable.define(symbol) {
            diagnostics.error("redeclaration of '\(t.name)'", at: t.span.start)
        }
    }

    private func gatherTypeAlias(_ ta: TypeAliasDecl) {
        let aliasedType = resolver.resolve(ta.type)
        let symbol = Symbol(name: ta.name, type: aliasedType, kind: .typeDeclaration, span: ta.span)
        if !symbolTable.define(symbol) {
            diagnostics.error("redeclaration of type '\(ta.name)'", at: ta.span.start)
        }
        symbolTable.registerType(TypeDeclInfo(name: ta.name))
    }

    // MARK: - Pass 2: Type Checking

    private func checkDeclaration(_ decl: Declaration) {
        switch decl {
        case .function(let f):
            checkFunction(f)
        case .property(let p):
            checkProperty(p)
        case .classDecl(let c):
            checkClass(c)
        case .interfaceDecl(let i):
            checkInterface(i)
        case .enumDecl(let e):
            checkEnumClass(e)
        case .objectDecl(let o):
            checkObject(o)
        case .actorDecl(let a):
            checkActor(a)
        case .viewDecl(let v):
            checkView(v)
        case .navigationDecl(let n):
            checkNavigation(n)
        case .themeDecl(let t):
            checkTheme(t)
        case .typeAlias:
            break // Already resolved in pass 1
        }
    }

    private func checkFunction(_ f: FunctionDecl) {
        symbolTable.pushScope()

        // Register type parameters
        for tp in f.typeParameters {
            let bound: Type? = tp.upperBound.map { resolver.resolve($0) }
            let tpType = Type.typeParameter(name: tp.name, bound: bound)
            symbolTable.define(Symbol(name: tp.name, type: tpType, kind: .typeParameter, span: tp.span))
        }

        // Register parameters
        for param in f.parameters {
            let paramType: Type
            if let typeNode = param.type {
                paramType = resolver.resolve(typeNode)
            } else {
                paramType = .error
            }
            symbolTable.define(Symbol(name: param.name, type: paramType, kind: .parameter, span: param.span))

            // Check default value
            if let defaultVal = param.defaultValue {
                let defaultType = checkExpression(defaultVal)
                if !paramType.isError && !defaultType.isError {
                    if !typesCompatible(source: defaultType, target: paramType) {
                        diagnostics.error(
                            "default value of type '\(defaultType)' is not compatible with parameter type '\(paramType)'",
                            at: param.span.start
                        )
                    }
                }
            }
        }

        // Check body
        if let body = f.body {
            switch body {
            case .block(let block):
                checkBlock(block)
            case .expression(let expr):
                let _ = checkExpression(expr)
            }
        }

        symbolTable.popScope()
    }

    private func checkProperty(_ p: PropertyDecl) {
        guard let initializer = p.initializer else { return }

        let initType = checkExpression(initializer)

        if let typeNode = p.type {
            let declaredType = resolver.resolve(typeNode)
            if !declaredType.isError && !initType.isError {
                if !typesCompatible(source: initType, target: declaredType) {
                    diagnostics.error(
                        "cannot assign '\(initType)' to '\(declaredType)'",
                        at: p.span.start
                    )
                }
            }
        } else {
            // Infer type from initializer — update symbol table
            if !initType.isError {
                let updatedSymbol = Symbol(
                    name: p.name,
                    type: initType,
                    kind: .variable(isMutable: !p.isVal),
                    span: p.span
                )
                // Re-define in current scope (replaces .error placeholder)
                symbolTable.currentScope.update(updatedSymbol)
            }
        }
    }

    private func checkClass(_ c: ClassDecl) {
        symbolTable.pushScope()

        // Register type parameters
        for tp in c.typeParameters {
            let bound: Type? = tp.upperBound.map { resolver.resolve($0) }
            let tpType = Type.typeParameter(name: tp.name, bound: bound)
            symbolTable.define(Symbol(name: tp.name, type: tpType, kind: .typeParameter, span: tp.span))
        }

        // Register constructor params as accessible members
        for param in c.constructorParams {
            let paramType: Type = param.type.map { resolver.resolve($0) } ?? .error
            symbolTable.define(Symbol(name: param.name, type: paramType, kind: .parameter, span: param.span))
        }

        // Pre-register member properties and functions so they're visible in method bodies
        for member in c.members {
            if case .property(let p) = member {
                let propType = p.type.map { resolver.resolve($0) } ?? .error
                symbolTable.define(Symbol(name: p.name, type: propType, kind: .variable(isMutable: !p.isVal), span: p.span))
            } else if case .function(let f) = member {
                let paramTypes = f.parameters.map { p -> Type in
                    p.type.map { resolver.resolve($0) } ?? .error
                }
                let retType = f.returnType.map { resolver.resolve($0) } ?? .unit
                symbolTable.define(Symbol(
                    name: f.name,
                    type: .function(parameterTypes: paramTypes, returnType: retType),
                    kind: .function, span: f.span
                ))
            }
        }

        // Check members
        for member in c.members {
            checkDeclaration(member)
        }

        // Check interface implementation: verify all required methods are provided
        if let classInfo = symbolTable.lookupType(c.name) {
            for superTypeName in classInfo.superTypes {
                if let ifaceInfo = symbolTable.lookupType(superTypeName),
                   !ifaceInfo.members.isEmpty {
                    // This is an interface — check that all its methods are implemented
                    let classMethods = Set(classInfo.members.filter {
                        if case .function = $0.kind { return true }
                        return false
                    }.map { $0.name })

                    for ifaceMember in ifaceInfo.members {
                        if case .function = ifaceMember.kind, !classMethods.contains(ifaceMember.name) {
                            diagnostics.error(
                                "class '\(c.name)' does not implement interface method '\(superTypeName).\(ifaceMember.name)'",
                                at: c.span.start
                            )
                        }
                    }
                }
            }
        }

        symbolTable.popScope()
    }

    private func checkInterface(_ i: InterfaceDecl) {
        symbolTable.pushScope()
        for tp in i.typeParameters {
            let bound: Type? = tp.upperBound.map { resolver.resolve($0) }
            let tpType = Type.typeParameter(name: tp.name, bound: bound)
            symbolTable.define(Symbol(name: tp.name, type: tpType, kind: .typeParameter, span: tp.span))
        }
        for member in i.members {
            checkDeclaration(member)
        }
        symbolTable.popScope()
    }

    private func checkEnumClass(_ e: EnumClassDecl) {
        // Check member declarations
        for member in e.members {
            checkDeclaration(member)
        }
    }

    private func checkObject(_ o: ObjectDecl) {
        symbolTable.pushScope()
        for member in o.members {
            checkDeclaration(member)
        }
        symbolTable.popScope()
    }

    private func checkActor(_ a: ActorDecl) {
        symbolTable.pushScope()
        for member in a.members {
            checkDeclaration(member)
        }
        symbolTable.popScope()
    }

    private func checkView(_ v: ViewDecl) {
        symbolTable.pushScope()
        for param in v.parameters {
            let paramType: Type = param.type.map { resolver.resolve($0) } ?? .error
            symbolTable.define(Symbol(name: param.name, type: paramType, kind: .parameter, span: param.span))
        }
        checkBlock(v.body)
        symbolTable.popScope()
    }

    private func checkNavigation(_ n: NavigationDecl) {
        symbolTable.pushScope()
        checkBlock(n.body)
        symbolTable.popScope()
    }

    private func checkTheme(_ t: ThemeDecl) {
        symbolTable.pushScope()
        checkBlock(t.body)
        symbolTable.popScope()
    }

    // MARK: - Block & Statement Checking

    private func checkBlock(_ block: Block) {
        symbolTable.pushScope()
        for stmt in block.statements {
            checkStatement(stmt)
        }
        symbolTable.popScope()
    }

    private func checkStatement(_ stmt: Statement) {
        switch stmt {
        case .expression(let expr):
            let _ = checkExpression(expr)

        case .propertyDecl(let p):
            // Gather into scope then check
            gatherProperty(p)
            checkProperty(p)

        case .returnStmt(let expr, _):
            if let expr = expr {
                let _ = checkExpression(expr)
            }

        case .throwStmt(let expr, _):
            let _ = checkExpression(expr)

        case .assignment(let a):
            checkAssignment(a)

        case .forLoop(let f):
            checkForLoop(f)

        case .whileLoop(let w):
            let condType = checkExpression(w.condition)
            if !condType.isError && condType != .bool {
                diagnostics.error("while condition must be Bool, got '\(condType)'", at: w.span.start)
            }
            checkBlock(w.body)

        case .doWhileLoop(let d):
            checkBlock(d.body)
            let condType = checkExpression(d.condition)
            if !condType.isError && condType != .bool {
                diagnostics.error("do-while condition must be Bool, got '\(condType)'", at: d.span.start)
            }

        case .declaration(let decl):
            gatherDeclaration(decl)
            checkDeclaration(decl)

        case .breakStmt, .continueStmt:
            break
        }
    }

    private func checkAssignment(_ a: AssignmentStmt) {
        let targetType = checkExpression(a.target)
        let valueType = checkExpression(a.value)

        // Check mutability
        if case .identifier(let name, let span) = a.target {
            if let sym = symbolTable.lookup(name) {
                if case .variable(let isMutable) = sym.kind, !isMutable {
                    diagnostics.error("cannot assign to 'val' property '\(name)'", at: span.start)
                }
            }
        }

        // Check type compatibility
        if !targetType.isError && !valueType.isError {
            if a.op == .assign {
                if !typesCompatible(source: valueType, target: targetType) {
                    diagnostics.error(
                        "cannot assign '\(valueType)' to '\(targetType)'",
                        at: a.span.start
                    )
                }
            } else {
                // Compound assignment: +=, -=, etc.
                if !checkCompoundAssignment(targetType: targetType, valueType: valueType, op: a.op) {
                    diagnostics.error(
                        "operator '\(a.op)' is not applicable for '\(targetType)' and '\(valueType)'",
                        at: a.span.start
                    )
                }
            }
        }
    }

    private func checkCompoundAssignment(targetType: Type, valueType: Type, op: AssignmentOp) -> Bool {
        switch op {
        case .plusAssign:
            return (targetType.isNumeric && valueType.isNumeric) ||
                   (targetType == .string && valueType == .string)
        case .minusAssign, .timesAssign, .divideAssign, .moduloAssign:
            return targetType.isNumeric && valueType.isNumeric
        case .assign:
            return true
        }
    }

    private func checkForLoop(_ f: ForLoop) {
        let iterableType = checkExpression(f.iterable)
        symbolTable.pushScope()

        // Infer loop variable type from iterable
        let varType: Type
        if case .classType(let name, let args) = iterableType,
           (name == "List" || name == "MutableList" || name == "Set" || name == "MutableSet"),
           let elementType = args.first {
            varType = elementType
        } else if iterableType.isError {
            varType = .error
        } else {
            // Ranges produce Int
            varType = .int
        }

        symbolTable.define(Symbol(name: f.variable, type: varType, kind: .variable(isMutable: false), span: f.span))
        checkBlock(f.body)
        symbolTable.popScope()
    }

    // MARK: - Expression Type Checking

    @discardableResult
    private func checkExpression(_ expr: Expression) -> Type {
        let type = inferExpression(expr)
        // Record in type map
        let id = ExpressionID(expr.span)
        typeMap[id] = type
        return type
    }

    private func inferExpression(_ expr: Expression) -> Type {
        switch expr {
        // Literals
        case .intLiteral:
            return .int
        case .floatLiteral:
            return .double
        case .stringLiteral:
            return .string
        case .interpolatedString(let parts, _):
            // Check each interpolation expression
            for part in parts {
                if case .interpolation(let subExpr) = part {
                    let _ = checkExpression(subExpr)
                }
            }
            return .string
        case .boolLiteral:
            return .bool
        case .nullLiteral:
            return .nullType

        // References
        case .identifier(let name, let span):
            if let sym = symbolTable.lookup(name) {
                return sym.type
            }
            diagnostics.error("unresolved reference '\(name)'", at: span.start)
            return .error

        case .this:
            // In class context, `this` refers to the enclosing class type
            // For Stage 0, return .error if we can't determine it
            return .error

        case .super:
            return .error

        // Binary
        case .binary(let left, let op, let right, let span):
            return checkBinary(left: left, op: op, right: right, span: span)

        // Unary prefix
        case .unaryPrefix(let op, let operand, let span):
            return checkUnaryPrefix(op: op, operand: operand, span: span)

        // Unary postfix
        case .unaryPostfix(let operand, let op, let span):
            return checkUnaryPostfix(operand: operand, op: op, span: span)

        // Member access
        case .memberAccess(let obj, let member, let span):
            return checkMemberAccess(object: obj, member: member, nullSafe: false, span: span)

        case .nullSafeMemberAccess(let obj, let member, let span):
            return checkMemberAccess(object: obj, member: member, nullSafe: true, span: span)

        // Subscript
        case .subscriptAccess(let obj, let index, _):
            let _ = checkExpression(obj)
            let _ = checkExpression(index)
            // For Stage 0, return .error — full subscript typing deferred
            return .error

        // Call
        case .call(let callee, let args, let trailing, let span):
            return checkCall(callee: callee, arguments: args, trailingLambda: trailing, span: span)

        // If expression
        case .ifExpr(let ie):
            return checkIfExpr(ie)

        // When expression
        case .whenExpr(let we):
            return checkWhenExpr(we)

        // Lambda
        case .lambda(let le):
            return checkLambda(le)

        // Type operations
        case .typeCheck(let expr, _, _):
            let exprType = checkExpression(expr)
            if exprType.isError { return .error }
            return .bool

        case .typeCast(let expr, let typeNode, _):
            let _ = checkExpression(expr)
            return resolver.resolve(typeNode)

        case .safeCast(let expr, let typeNode, _):
            let _ = checkExpression(expr)
            let targetType = resolver.resolve(typeNode)
            if targetType.isError { return .error }
            return .nullable(targetType)

        case .nonNullAssert(let expr, let span):
            let exprType = checkExpression(expr)
            if exprType.isError { return .error }
            if !exprType.isNullable {
                diagnostics.warning("unnecessary non-null assertion on non-nullable type '\(exprType)'", at: span.start)
                return exprType
            }
            return exprType.unwrapNullable

        // Elvis
        case .elvis(let left, let right, let span):
            return checkElvis(left: left, right: right, span: span)

        // Range
        case .range(let start, let end, _, let span):
            let startType = checkExpression(start)
            let endType = checkExpression(end)
            if !startType.isError && !startType.isInteger {
                diagnostics.error("range start must be integer, got '\(startType)'", at: span.start)
            }
            if !endType.isError && !endType.isInteger {
                diagnostics.error("range end must be integer, got '\(endType)'", at: span.start)
            }
            return .classType(name: "IntRange", typeArguments: [])

        // Parenthesized
        case .parenthesized(let inner, _):
            return checkExpression(inner)

        // Error
        case .error:
            return .error
        }
    }

    // MARK: - Binary Operations

    private func checkBinary(left: Expression, op: BinaryOp, right: Expression, span: SourceSpan) -> Type {
        let leftType = checkExpression(left)
        let rightType = checkExpression(right)

        if leftType.isError || rightType.isError { return .error }

        switch op {
        case .plus:
            if leftType == .string || rightType == .string {
                return .string
            }
            if leftType.isNumeric && rightType.isNumeric {
                return promoteNumeric(leftType, rightType)
            }
            diagnostics.error("operator '+' cannot be applied to '\(leftType)' and '\(rightType)'", at: span.start)
            return .error

        case .minus, .times, .divide, .modulo:
            if leftType.isNumeric && rightType.isNumeric {
                return promoteNumeric(leftType, rightType)
            }
            diagnostics.error("operator '\(op.rawValue)' cannot be applied to '\(leftType)' and '\(rightType)'", at: span.start)
            return .error

        case .equalEqual, .notEqual:
            // Any two values can be compared for equality
            return .bool

        case .less, .lessEqual, .greater, .greaterEqual:
            if leftType.isNumeric && rightType.isNumeric {
                return .bool
            }
            if leftType == .string && rightType == .string {
                return .bool
            }
            diagnostics.error("operator '\(op.rawValue)' cannot be applied to '\(leftType)' and '\(rightType)'", at: span.start)
            return .error

        case .and, .or:
            if leftType != .bool {
                diagnostics.error("left operand of '\(op.rawValue)' must be Bool, got '\(leftType)'", at: span.start)
                return .error
            }
            if rightType != .bool {
                diagnostics.error("right operand of '\(op.rawValue)' must be Bool, got '\(rightType)'", at: span.start)
                return .error
            }
            return .bool
        }
    }

    private func promoteNumeric(_ a: Type, _ b: Type) -> Type {
        // Double > Float64 > Float > Int64 > Int32 > Int
        if a == .double || b == .double { return .double }
        if a == .float64 || b == .float64 { return .float64 }
        if a == .float || b == .float { return .float }
        if a == .int64 || b == .int64 { return .int64 }
        if a == .int32 || b == .int32 { return .int32 }
        return .int
    }

    // MARK: - Unary Operations

    private func checkUnaryPrefix(op: UnaryOp, operand: Expression, span: SourceSpan) -> Type {
        let operandType = checkExpression(operand)
        if operandType.isError { return .error }

        switch op {
        case .negate:
            if operandType.isNumeric { return operandType }
            diagnostics.error("unary '-' cannot be applied to '\(operandType)'", at: span.start)
            return .error
        case .not:
            if operandType == .bool { return .bool }
            diagnostics.error("unary '!' cannot be applied to '\(operandType)'", at: span.start)
            return .error
        }
    }

    private func checkUnaryPostfix(operand: Expression, op: PostfixOp, span: SourceSpan) -> Type {
        let operandType = checkExpression(operand)
        if operandType.isError { return .error }

        switch op {
        case .nonNullAssert:
            if !operandType.isNullable {
                diagnostics.warning("unnecessary non-null assertion on non-nullable type '\(operandType)'", at: span.start)
                return operandType
            }
            return operandType.unwrapNullable
        }
    }

    // MARK: - Member Access

    private func checkMemberAccess(object: Expression, member: String, nullSafe: Bool, span: SourceSpan) -> Type {
        let objType = checkExpression(object)
        if objType.isError { return .error }

        let baseType: Type
        if nullSafe {
            if !objType.isNullable {
                diagnostics.warning("unnecessary null-safe access on non-nullable type '\(objType)'", at: span.start)
            }
            baseType = objType.unwrapNullable
        } else {
            if objType.isNullable && objType != .nullType {
                diagnostics.error("member access on nullable type '\(objType)' requires '?.' operator", at: span.start)
                return .error
            }
            baseType = objType
        }

        // Look up member in type declaration
        if let typeName = baseType.typeName,
           let typeInfo = symbolTable.lookupType(typeName) {
            if let memberSym = typeInfo.members.first(where: { $0.name == member }) {
                let resultType = memberSym.type
                return nullSafe ? resultType.asNullable : resultType
            }
        }

        // For String, provide common members
        if baseType == .string {
            switch member {
            case "length": return nullSafe ? Type.int.asNullable : .int
            case "isEmpty": return nullSafe ? Type.bool.asNullable : .bool
            default: break
            }
        }

        // For Stage 0, allow unknown member access with a warning-free .error
        // to avoid noise from unresolved stdlib members
        return .error
    }

    // MARK: - Call

    private func checkCall(callee: Expression, arguments: [CallArgument], trailingLambda: LambdaExpr?, span: SourceSpan) -> Type {
        let calleeType = checkExpression(callee)

        // Check arguments
        for arg in arguments {
            let _ = checkExpression(arg.value)
        }

        // Check trailing lambda
        if let lambda = trailingLambda {
            let _ = checkLambda(lambda)
        }

        if calleeType.isError { return .error }

        // If callee is a function type, return its return type
        if case .function(let paramTypes, let returnType) = calleeType {
            let totalArgs = arguments.count + (trailingLambda != nil ? 1 : 0)
            if totalArgs != paramTypes.count {
                // Allow variadic-like built-in functions (println accepts any number)
                // For Stage 0, just warn if significantly off
                // Skip strict arity check for builtins
            }
            return returnType
        }

        // If callee is a type (constructor call), return that type
        if case .classType(let name, let args) = calleeType {
            return .classType(name: name, typeArguments: args)
        }
        if case .enumType(let name) = calleeType {
            return .enumType(name: name)
        }

        // For identifiers that resolve to type declarations, treat as constructor
        if case .identifier(let name, _) = callee {
            if let sym = symbolTable.lookup(name), sym.kind == .typeDeclaration {
                return sym.type
            }
        }

        return .error
    }

    // MARK: - If Expression

    private func checkIfExpr(_ ie: IfExpr) -> Type {
        let condType = checkExpression(ie.condition)
        if !condType.isError && condType != .bool {
            diagnostics.error("if condition must be Bool, got '\(condType)'", at: ie.span.start)
        }

        checkBlock(ie.thenBranch)

        if let elseBranch = ie.elseBranch {
            switch elseBranch {
            case .elseBlock(let block):
                checkBlock(block)
            case .elseIf(let elseIf):
                let _ = checkIfExpr(elseIf)
            }
        }

        // For Stage 0, if used as expression, we'd need to unify branch types.
        // Simplified: return Unit for now.
        return .unit
    }

    // MARK: - When Expression

    private func checkWhenExpr(_ we: WhenExpr) -> Type {
        var subjectType: Type = .error
        if let subject = we.subject {
            subjectType = checkExpression(subject)
        }

        var hasElse = false
        var coveredTypes: [String] = []
        var branchTypes: [Type] = []

        for entry in we.entries {
            symbolTable.pushScope()

            for condition in entry.conditions {
                switch condition {
                case .expression(let expr):
                    if case .identifier(let name, _) = expr, name == "else" {
                        hasElse = true
                    } else {
                        let _ = checkExpression(expr)
                        // Detect enum entry references for exhaustiveness (e.g., Color.RED → "RED")
                        if let entryName = extractEnumEntryName(expr) {
                            coveredTypes.append(entryName)
                        }
                    }
                case .isType(let typeNode, _):
                    let resolvedType = resolver.resolve(typeNode)
                    if let name = resolvedType.typeName {
                        coveredTypes.append(name)
                    }
                    // Smart cast: narrow subject type in this scope
                    if let subject = we.subject,
                       case .identifier(let subjectName, let subjectSpan) = subject {
                        let narrowed = Symbol(
                            name: subjectName,
                            type: resolvedType,
                            kind: .variable(isMutable: false),
                            span: subjectSpan
                        )
                        symbolTable.currentScope.update(narrowed)
                    }
                }
            }

            switch entry.body {
            case .expression(let expr):
                let bodyType = checkExpression(expr)
                branchTypes.append(bodyType)
            case .block(let block):
                checkBlock(block)
                branchTypes.append(.unit)
            }

            symbolTable.popScope()
        }

        // Sealed class exhaustiveness check
        if !subjectType.isError, let typeName = subjectType.typeName,
           let typeInfo = symbolTable.lookupType(typeName),
           !typeInfo.sealedSubclasses.isEmpty {
            checkSealedExhaustiveness(
                subclasses: typeInfo.sealedSubclasses,
                coveredTypes: coveredTypes,
                hasElse: hasElse,
                span: we.span
            )
        }

        // Enum exhaustiveness check
        if !subjectType.isError, let typeName = subjectType.typeName,
           let typeInfo = symbolTable.lookupType(typeName),
           !typeInfo.enumEntries.isEmpty {
            checkEnumExhaustiveness(
                entries: typeInfo.enumEntries,
                coveredTypes: coveredTypes,
                hasElse: hasElse,
                span: we.span
            )
        }

        // Infer when-expression return type from branch types
        if let firstType = branchTypes.first,
           branchTypes.allSatisfy({ $0 == firstType || $0.isError }) {
            return firstType
        }
        return .unit
    }

    private func checkSealedExhaustiveness(subclasses: [String], coveredTypes: [String], hasElse: Bool, span: SourceSpan) {
        if hasElse { return }
        let missing = subclasses.filter { !coveredTypes.contains($0) }
        if !missing.isEmpty {
            let missingStr = missing.joined(separator: ", ")
            diagnostics.error("'when' is not exhaustive; missing: \(missingStr)", at: span.start)
        }
    }

    private func checkEnumExhaustiveness(entries: [String], coveredTypes: [String], hasElse: Bool, span: SourceSpan) {
        if hasElse { return }
        let missing = entries.filter { !coveredTypes.contains($0) }
        if !missing.isEmpty {
            let missingStr = missing.joined(separator: ", ")
            diagnostics.error("'when' is not exhaustive; missing: \(missingStr)", at: span.start)
        }
    }

    /// Extract the enum entry name from a when condition expression.
    /// Handles `EnumType.ENTRY` (memberAccess) and bare `ENTRY` (identifier that's an enumEntry symbol).
    private func extractEnumEntryName(_ expr: Expression) -> String? {
        // Pattern: EnumType.ENTRY (e.g., Color.RED)
        if case .memberAccess(let obj, let member, _) = expr,
           case .identifier(let typeName, _) = obj,
           let typeInfo = symbolTable.lookupType(typeName),
           !typeInfo.enumEntries.isEmpty,
           typeInfo.enumEntries.contains(member) {
            return member
        }
        // Pattern: bare ENTRY name (if imported/in scope as enum entry)
        if case .identifier(let name, _) = expr,
           let sym = symbolTable.lookup(name),
           sym.kind == .enumEntry {
            return name
        }
        return nil
    }

    // MARK: - Lambda

    @discardableResult
    private func checkLambda(_ le: LambdaExpr) -> Type {
        symbolTable.pushScope()

        let paramTypes: [Type] = le.parameters.map { param in
            let type: Type = param.type.map { resolver.resolve($0) } ?? .error
            symbolTable.define(Symbol(name: param.name, type: type, kind: .parameter, span: param.span))
            return type
        }

        for stmt in le.body {
            checkStatement(stmt)
        }

        symbolTable.popScope()

        // If parameters have no types, this is an untyped lambda — return .error for now
        if paramTypes.contains(where: { $0.isError }) && !le.parameters.isEmpty {
            return .error
        }

        return .function(parameterTypes: paramTypes, returnType: .unit)
    }

    // MARK: - Elvis

    private func checkElvis(left: Expression, right: Expression, span: SourceSpan) -> Type {
        let leftType = checkExpression(left)
        let rightType = checkExpression(right)

        if leftType.isError || rightType.isError { return .error }

        if !leftType.isNullable {
            diagnostics.warning("left operand of '?:' is not nullable; elvis operator is unnecessary", at: span.start)
            return leftType
        }

        // Result is the non-nullable left type, or the right type — whichever is broader
        let unwrapped = leftType.unwrapNullable
        if typesCompatible(source: rightType, target: unwrapped) {
            return unwrapped
        }
        // If right type differs, result is their common supertype — for Stage 0, use right type
        return rightType
    }

    // MARK: - Type Compatibility

    /// Check if `source` can be assigned to `target`
    private func typesCompatible(source: Type, target: Type) -> Bool {
        if source == target { return true }
        if source.isError || target.isError { return true } // Suppress cascading
        if source == .nothing { return true } // Nothing is a subtype of everything
        if source == .nullType && target.isNullable { return true } // null → T?

        // Numeric widening
        if target.isNumeric && source.isNumeric {
            return numericRank(source) <= numericRank(target)
        }

        // Nullable compatibility: T is compatible with T?
        if case .nullable(let inner) = target {
            return typesCompatible(source: source, target: inner)
        }

        return false
    }

    private func numericRank(_ type: Type) -> Int {
        switch type {
        case .int:     return 1
        case .int32:   return 2
        case .int64:   return 3
        case .float:   return 4
        case .float64: return 5
        case .double:  return 6
        default:       return 0
        }
    }
}

// MARK: - Expression Span Helper

extension Expression {
    /// Extract the source span from an expression
    var span: SourceSpan {
        switch self {
        case .intLiteral(_, let s),
             .floatLiteral(_, let s),
             .stringLiteral(_, let s),
             .interpolatedString(_, let s),
             .boolLiteral(_, let s),
             .nullLiteral(let s),
             .identifier(_, let s),
             .this(let s),
             .super(let s),
             .error(let s):
            return s
        case .binary(_, _, _, let span),
             .memberAccess(_, _, let span),
             .nullSafeMemberAccess(_, _, let span),
             .subscriptAccess(_, _, let span),
             .call(_, _, _, let span),
             .typeCheck(_, _, let span),
             .typeCast(_, _, let span),
             .safeCast(_, _, let span),
             .nonNullAssert(_, let span),
             .elvis(_, _, let span),
             .range(_, _, _, let span),
             .parenthesized(_, let span):
            return span
        case .unaryPrefix(_, _, let span):
            return span
        case .unaryPostfix(_, _, let span):
            return span
        case .ifExpr(let ie):
            return ie.span
        case .whenExpr(let we):
            return we.span
        case .lambda(let le):
            return le.span
        }
    }
}
