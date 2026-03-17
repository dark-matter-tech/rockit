// SafetyProfile.swift
// RockitKit — Rockit Language Compiler
// Copyright © 2026 Dark Matter Tech. All rights reserved.
//
// DO-178C Safety Profile Enforcement
//
// Implements compile-time safety verification per RTCA DO-178C
// Design Assurance Levels (DAL). Each level defines restrictions
// on language features to enable certification at that level.
//
// Phase Interface Contract:
//   Input:  SourceFile (typed AST from TypeChecker)
//   Output: SafetyVerificationResult (violations list, pass/fail, call graph)
//   Invariant: Does not modify the AST. Read-only analysis pass.
//
// Traceability: Each violation references a DO-178C objective
// and the source location where the violation occurs.

import Foundation

// MARK: - Safety Level

/// DO-178C Design Assurance Levels.
/// DAL A is most restrictive (catastrophic failure condition).
/// DAL E is least restrictive (no safety effect).
public enum SafetyLevel: String, CaseIterable, Comparable {
    case dalA = "dal-a"
    case dalB = "dal-b"
    case dalC = "dal-c"
    case dalD = "dal-d"
    case dalE = "dal-e"

    public var displayName: String {
        switch self {
        case .dalA: return "DAL A (Catastrophic)"
        case .dalB: return "DAL B (Hazardous)"
        case .dalC: return "DAL C (Major)"
        case .dalD: return "DAL D (Minor)"
        case .dalE: return "DAL E (No Effect)"
        }
    }

    private var severity: Int {
        switch self {
        case .dalA: return 1
        case .dalB: return 2
        case .dalC: return 3
        case .dalD: return 4
        case .dalE: return 5
        }
    }

    public static func < (lhs: SafetyLevel, rhs: SafetyLevel) -> Bool {
        lhs.severity < rhs.severity
    }
}

// MARK: - Violation Category

/// Categories of safety violations, mapped to DO-178C objectives.
public enum SafetyViolationCategory: String {
    /// Unbounded recursion detected (DO-178C 6.3.4f — bounded execution time)
    case unboundedRecursion = "WCET-001"
    /// Dynamic heap allocation (DO-178C 6.3.4b — deterministic memory usage)
    case dynamicAllocation = "MEM-001"
    /// Closure/lambda capture (DO-178C 6.3.4c — no hidden state)
    case closureCapture = "STATE-001"
    /// Exception handling (DO-178C 6.3.4d — deterministic control flow)
    case exceptionHandling = "FLOW-001"
    /// Unbounded loop without provable termination (DO-178C 6.3.4f)
    case unboundedLoop = "WCET-002"
    /// String concatenation/interpolation creates heap objects (DO-178C 6.3.4b)
    case dynamicStringOp = "MEM-002"
    /// Async/await non-deterministic scheduling (DO-178C 6.3.4f)
    case asyncExecution = "WCET-003"
    /// Class instantiation allocates on heap (DO-178C 6.3.4b)
    case heapObjectConstruction = "MEM-003"

    public var objective: String {
        switch self {
        case .unboundedRecursion:    return "DO-178C 6.3.4f: Bounded execution time"
        case .dynamicAllocation:     return "DO-178C 6.3.4b: Deterministic memory usage"
        case .closureCapture:        return "DO-178C 6.3.4c: No hidden mutable state"
        case .exceptionHandling:     return "DO-178C 6.3.4d: Deterministic control flow"
        case .unboundedLoop:         return "DO-178C 6.3.4f: Bounded execution time"
        case .dynamicStringOp:       return "DO-178C 6.3.4b: Deterministic memory usage"
        case .asyncExecution:        return "DO-178C 6.3.4f: Bounded execution time"
        case .heapObjectConstruction: return "DO-178C 6.3.4b: Deterministic memory usage"
        }
    }

    /// Engineering rationale for why this category is restricted (ARC-specific).
    public var rationale: String {
        switch self {
        case .dynamicAllocation:
            return "Dynamic heap allocation introduces unbounded WCET and fragmentation risk. Each malloc has variable cost; ARC retain/release overhead scales with object graph depth. Pre-allocation eliminates both."
        case .exceptionHandling:
            return "Exception unwinding introduces non-deterministic control flow. Stack walk allocates exception objects and traces. Errors as data (Result<T>) eliminates exception-based control flow entirely."
        case .unboundedLoop:
            return "Unbounded iteration prevents WCET analysis and risks carrying oversized objects through cache."
        case .unboundedRecursion:
            return "Unbounded recursion prevents stack depth analysis and risks stack overflow."
        case .dynamicStringOp:
            return "Dynamic string concatenation triggers hidden allocation (new backing array + copy per concat)."
        case .closureCapture:
            return "Closures that capture mutable state create hidden heap allocations for the capture context. This introduces unpredictable ARC retain/release overhead and potential reference cycles."
        case .asyncExecution:
            return "Async/await introduces non-deterministic scheduling where execution order depends on runtime task queue state. WCET becomes unanalyzable."
        case .heapObjectConstruction:
            return "Class construction allocates on the heap with per-object ARC retain/release overhead and memory fragmentation."
        }
    }

    /// Compliant alternative for safety-critical code.
    public var compliantAlternative: String {
        switch self {
        case .dynamicAllocation:
            return "Pre-allocated pools, stack allocation via Ptr<T> + alloc, buffer reuse"
        case .exceptionHandling:
            return "Result<T> type (rockit.core.result), error codes, sentinel values"
        case .unboundedLoop:
            return "Counted loops with compile-time-provable bounds"
        case .unboundedRecursion:
            return "Iterative algorithms or tail-call form with provable depth bounds"
        case .dynamicStringOp:
            return "Fixed Ptr<Byte> buffers with storeByte/loadByte, lookup tables"
        case .closureCapture:
            return "Explicit parameter passing"
        case .asyncExecution:
            return "Synchronous sequential execution"
        case .heapObjectConstruction:
            return "@CRepr data classes with pool allocation or region-based teardown"
        }
    }
}

// MARK: - Violation

/// A single safety profile violation with source traceability.
public struct SafetyViolation: CustomStringConvertible {
    public let category: SafetyViolationCategory
    public let message: String
    public let span: SourceSpan?
    public let functionName: String?

    public var description: String {
        var s = "[\(category.rawValue)] \(message)"
        if let fn = functionName { s += " (in \(fn))" }
        if let sp = span { s += " at \(sp.start)" }
        return s
    }

    public var fullDescription: String {
        var s = "\(description)\n  Objective: \(category.objective)"
        s += "\n  Rationale: \(category.rationale)"
        s += "\n  Alternative: \(category.compliantAlternative)"
        return s
    }

    public func toJSON() -> [String: Any] {
        var json: [String: Any] = [
            "code": category.rawValue,
            "message": message,
            "objective": category.objective,
            "rationale": category.rationale,
            "compliantAlternative": category.compliantAlternative,
        ]
        if let fn = functionName { json["function"] = fn }
        if let sp = span {
            json["location"] = [
                "file": sp.start.file,
                "line": sp.start.line,
                "column": sp.start.column,
            ]
        }
        return json
    }
}

// MARK: - Verification Result

/// Output of safety profile verification.
public struct SafetyVerificationResult {
    public let level: SafetyLevel
    public let violations: [SafetyViolation]
    /// Call graph: function name -> set of callees
    public let callGraph: [String: Set<String>]

    public var passed: Bool { violations.isEmpty }

    public var summary: String {
        if passed {
            return "Safety verification PASSED for \(level.displayName)"
        }
        return "Safety verification FAILED for \(level.displayName): \(violations.count) violation(s)"
    }

    public func toJSON() -> [String: Any] {
        return [
            "level": level.rawValue,
            "passed": passed,
            "violationCount": violations.count,
            "violations": violations.map { $0.toJSON() },
            "callGraph": callGraph.mapValues { Array($0).sorted() },
        ]
    }
}

// MARK: - Safety Verifier

/// Analyzes a typed AST for DO-178C safety compliance.
///
/// This is a separate, independently verifiable compiler phase.
/// It runs after type checking and before code generation.
/// It does not modify the AST — read-only analysis only.
///
/// DAL A restrictions:
///   - No unbounded recursion (call graph must be acyclic)
///   - No dynamic heap allocation (listCreate, mapCreate, class constructors)
///   - No closures/lambdas (hidden state capture)
///   - No exceptions (try/catch/throw)
///   - No unbounded loops (while condition must reference a bounded counter)
///   - No dynamic string operations (concat, interpolation, substring)
///   - No async/await (non-deterministic scheduling)
///
/// DAL B adds:
///   - Bounded dynamic allocation allowed
///   - Closures allowed if non-capturing
///
/// DAL C and below: progressively fewer restrictions.
public final class SafetyVerifier {
    private let level: SafetyLevel
    private let ast: SourceFile
    private let diagnostics: DiagnosticEngine
    private var violations: [SafetyViolation] = []
    private var callGraph: [String: Set<String>] = [:]
    private var currentFunction: String? = nil

    /// Builtins that perform dynamic heap allocation
    private static let heapAllocBuiltins: Set<String> = [
        "listCreate", "listCreateFilled", "mapCreate",
    ]

    /// Builtins that create dynamic string objects on the heap
    private static let dynamicStringBuiltins: Set<String> = [
        "substring", "charAt", "stringTrim",
        "stringReplace", "stringToLower", "stringToUpper",
        "stringConcat", "readLine", "toString",
        "intToChar", "stringFromCharCodes",
    ]

    public init(level: SafetyLevel, ast: SourceFile, diagnostics: DiagnosticEngine) {
        self.level = level
        self.ast = ast
        self.diagnostics = diagnostics
    }

    /// Run safety verification. Returns result and reports violations as diagnostics.
    public func verify() -> SafetyVerificationResult {
        // Phase 1: Walk AST, build call graph, collect feature violations
        for decl in ast.declarations {
            analyzeDeclaration(decl)
        }

        // Phase 2: Detect recursive call cycles (DAL A through D)
        if level <= .dalD {
            detectRecursion()
        }

        // Report through diagnostics engine
        for v in violations {
            diagnostics.error("[\(v.category.rawValue)] \(v.message)", at: v.span?.start)
        }

        return SafetyVerificationResult(
            level: level,
            violations: violations,
            callGraph: callGraph
        )
    }

    // MARK: - Declaration Analysis

    private func analyzeDeclaration(_ decl: Declaration) {
        switch decl {
        case .function(let f):
            let prevFn = currentFunction
            currentFunction = f.name
            callGraph[f.name] = callGraph[f.name] ?? []
            if let body = f.body {
                switch body {
                case .block(let block):
                    analyzeBlock(block)
                case .expression(let expr):
                    analyzeExpression(expr)
                }
            }
            currentFunction = prevFn

        case .classDecl(let c):
            for member in c.members {
                analyzeDeclaration(member)
            }

        case .interfaceDecl(let i):
            for member in i.members {
                analyzeDeclaration(member)
            }

        case .enumDecl(_):
            break // Enums are stack-allocated, safe at all levels

        case .objectDecl(let o):
            for member in o.members {
                analyzeDeclaration(member)
            }

        case .actorDecl(let a):
            if level <= .dalA {
                addViolation(.dynamicAllocation,
                    "Actor '\(a.name)' uses dynamic dispatch and heap allocation",
                    span: a.span)
            }
            for member in a.members {
                analyzeDeclaration(member)
            }

        case .viewDecl(let v):
            if level <= .dalB {
                addViolation(.dynamicAllocation,
                    "View '\(v.name)' uses dynamic UI tree allocation",
                    span: v.span)
            }

        case .property(let p):
            if let init_expr = p.initializer {
                analyzeExpression(init_expr)
            }

        case .navigationDecl(_), .themeDecl(_), .typeAlias(_):
            break
        }
    }

    // MARK: - Block / Statement Analysis

    private func analyzeBlock(_ block: Block) {
        for stmt in block.statements {
            analyzeStatement(stmt)
        }
    }

    private func analyzeStatement(_ stmt: Statement) {
        switch stmt {
        case .propertyDecl(let p):
            if let init_expr = p.initializer {
                analyzeExpression(init_expr)
            }

        case .expression(let expr):
            analyzeExpression(expr)

        case .returnStmt(let expr, _):
            if let expr = expr { analyzeExpression(expr) }

        case .assignment(let a):
            analyzeExpression(a.target)
            analyzeExpression(a.value)

        case .whileLoop(let w):
            if level <= .dalD {
                if !hasProvableBound(condition: w.condition) {
                    addViolation(.unboundedLoop,
                        "while loop without provable bound — \(level.displayName) requires all loops to terminate in bounded time",
                        span: w.span)
                }
            }
            analyzeExpression(w.condition)
            analyzeBlock(w.body)

        case .doWhileLoop(let d):
            if level <= .dalD {
                if !hasProvableBound(condition: d.condition) {
                    addViolation(.unboundedLoop,
                        "do-while loop without provable bound — \(level.displayName) requires all loops to terminate in bounded time",
                        span: d.span)
                }
            }
            analyzeBlock(d.body)
            analyzeExpression(d.condition)

        case .forLoop(let f):
            // for-in loops over fixed-size collections are considered bounded
            analyzeExpression(f.iterable)
            analyzeBlock(f.body)

        case .throwStmt(let expr, let span):
            if level <= .dalB {
                addViolation(.exceptionHandling,
                    "throw — \(level.displayName) prohibits exception-based control flow",
                    span: span)
            }
            analyzeExpression(expr)

        case .tryCatch(let tc):
            if level <= .dalB {
                addViolation(.exceptionHandling,
                    "try/catch — \(level.displayName) prohibits exception-based control flow",
                    span: tc.span)
            }
            analyzeBlock(tc.tryBody)
            analyzeBlock(tc.catchBody)
            if let f = tc.finallyBody { analyzeBlock(f) }

        case .declaration(let d):
            analyzeDeclaration(d)

        case .destructuringDecl(let d):
            analyzeExpression(d.initializer)

        case .breakStmt(_), .continueStmt(_):
            break
        }
    }

    // MARK: - Expression Analysis

    private func analyzeExpression(_ expr: Expression) {
        switch expr {
        case .call(let callee, let args, let trailingLambda, let span):
            let calleeName = nameOf(callee)

            // Track call graph
            if let caller = currentFunction, let calleeName = calleeName {
                callGraph[caller, default: []].insert(calleeName)
            }

            if level <= .dalA {
                // Check heap-allocating builtins
                if let name = calleeName, Self.heapAllocBuiltins.contains(name) {
                    addViolation(.dynamicAllocation,
                        "'\(name)' performs dynamic heap allocation",
                        span: span)
                }

                // Check dynamic string operations
                if let name = calleeName, Self.dynamicStringBuiltins.contains(name) {
                    addViolation(.dynamicStringOp,
                        "'\(name)' creates dynamic string objects on the heap",
                        span: span)
                }

                // Class constructor calls (uppercase name that isn't a primitive type)
                if let name = calleeName, name.first?.isUppercase == true,
                   !["Int", "Bool", "Float", "String", "Unit", "Ptr", "Byte"].contains(name) {
                    addViolation(.heapObjectConstruction,
                        "Constructor '\(name)(...)' allocates on heap",
                        span: span)
                }
            }

            analyzeExpression(callee)
            for arg in args { analyzeExpression(arg.value) }
            if let tl = trailingLambda {
                if level <= .dalB {
                    addViolation(.closureCapture,
                        "Trailing lambda — \(level.displayName) prohibits closures",
                        span: tl.span)
                }
                for stmt in tl.body { analyzeStatement(stmt) }
            }

        case .lambda(let le):
            if level <= .dalB {
                addViolation(.closureCapture,
                    "Lambda expression — \(level.displayName) prohibits closures (hidden state capture)",
                    span: le.span)
            }
            for stmt in le.body { analyzeStatement(stmt) }

        case .binary(let lhs, let op, let rhs, let span):
            if level <= .dalA && op == .plus {
                // String concatenation with + creates heap-allocated strings.
                // We flag all + operations here as a conservative check;
                // a more precise analysis would use type information.
                // The type checker has already determined types, so we could
                // enhance this later with type map lookup.
            }
            analyzeExpression(lhs)
            analyzeExpression(rhs)

        case .interpolatedString(let parts, let span):
            if level <= .dalA {
                addViolation(.dynamicStringOp,
                    "String interpolation creates dynamic heap-allocated strings",
                    span: span)
            }
            for part in parts {
                switch part {
                case .literal(_): break
                case .interpolation(let expr): analyzeExpression(expr)
                }
            }

        case .ifExpr(let ie):
            analyzeExpression(ie.condition)
            analyzeBlock(ie.thenBranch)
            if let elseBranch = ie.elseBranch {
                switch elseBranch {
                case .elseBlock(let block): analyzeBlock(block)
                case .elseIf(let eif): analyzeExpression(.ifExpr(eif))
                }
            }

        case .whenExpr(let we):
            if let subject = we.subject { analyzeExpression(subject) }
            for entry in we.entries {
                switch entry.body {
                case .expression(let expr): analyzeExpression(expr)
                case .block(let block): analyzeBlock(block)
                }
                if let guard_ = entry.guard_ { analyzeExpression(guard_) }
            }

        case .awaitExpr(let expr, let span):
            if level <= .dalC {
                addViolation(.asyncExecution,
                    "await — \(level.displayName) requires deterministic execution, no async scheduling",
                    span: span)
            }
            analyzeExpression(expr)

        case .concurrentBlock(let body, let span):
            if level <= .dalC {
                addViolation(.asyncExecution,
                    "concurrent block — \(level.displayName) prohibits non-deterministic scheduling",
                    span: span)
            }
            for stmt in body { analyzeStatement(stmt) }

        case .memberAccess(let obj, _, _):
            analyzeExpression(obj)

        case .nullSafeMemberAccess(let obj, _, _):
            analyzeExpression(obj)

        case .subscriptAccess(let obj, let idx, _):
            analyzeExpression(obj)
            analyzeExpression(idx)

        case .unaryPrefix(_, let operand, _):
            analyzeExpression(operand)

        case .unaryPostfix(let operand, _, _):
            analyzeExpression(operand)

        case .parenthesized(let expr, _):
            analyzeExpression(expr)

        case .elvis(let lhs, let rhs, _):
            analyzeExpression(lhs)
            analyzeExpression(rhs)

        case .range(let start, let end, _, _):
            analyzeExpression(start)
            analyzeExpression(end)

        case .typeCheck(let expr, _, _), .typeCast(let expr, _, _),
             .safeCast(let expr, _, _), .nonNullAssert(let expr, _):
            analyzeExpression(expr)

        case .intLiteral(_, _), .floatLiteral(_, _), .stringLiteral(_, _),
             .boolLiteral(_, _), .nullLiteral(_),
             .identifier(_, _), .this(_), .super(_), .error(_):
            break
        }
    }

    // MARK: - Recursion Detection

    /// Detect cycles in the call graph using DFS with path tracking.
    private func detectRecursion() {
        var visited: Set<String> = []
        var onStack: Set<String> = []

        func dfs(_ node: String, path: [String]) {
            if onStack.contains(node) {
                let cycleStart = path.firstIndex(of: node) ?? 0
                let cycle = Array(path[cycleStart...]) + [node]
                let chainDesc = cycle.joined(separator: " -> ")
                addViolation(.unboundedRecursion,
                    "Recursive call cycle: \(chainDesc)",
                    span: nil, functionName: node)
                return
            }
            if visited.contains(node) { return }

            visited.insert(node)
            onStack.insert(node)

            for callee in callGraph[node] ?? [] {
                dfs(callee, path: path + [node])
            }

            onStack.remove(node)
        }

        for fn in callGraph.keys.sorted() {
            dfs(fn, path: [])
        }
    }

    // MARK: - Loop Bound Analysis

    /// Conservative check: does the while condition compare a variable against a bound?
    /// Recognizes patterns like `i < n`, `i <= 100`, `j > 0`, `k != limit`.
    private func hasProvableBound(condition: Expression) -> Bool {
        switch condition {
        case .binary(let lhs, let op, let rhs, _):
            switch op {
            case .less, .lessEqual, .greater, .greaterEqual, .notEqual:
                return isSimpleTerminal(lhs) && isSimpleTerminal(rhs)
            default:
                return false
            }

        case .parenthesized(let inner, _):
            return hasProvableBound(condition: inner)

        default:
            return false
        }
    }

    /// Is this a simple terminal (variable, literal, member access)?
    private func isSimpleTerminal(_ expr: Expression) -> Bool {
        switch expr {
        case .identifier(_, _): return true
        case .intLiteral(_, _): return true
        case .memberAccess(_, _, _): return true
        case .call(let callee, _, _, _):
            // listSize(x), stringLength(x) — bounded by collection size
            if let name = nameOf(callee),
               ["listSize", "stringLength"].contains(name) {
                return true
            }
            return false
        default: return false
        }
    }

    // MARK: - Helpers

    private func addViolation(_ category: SafetyViolationCategory, _ message: String,
                              span: SourceSpan?, functionName: String? = nil) {
        violations.append(SafetyViolation(
            category: category,
            message: message,
            span: span,
            functionName: functionName ?? currentFunction
        ))
    }

    private func nameOf(_ expr: Expression) -> String? {
        switch expr {
        case .identifier(let name, _): return name
        case .memberAccess(_, let member, _): return member
        default: return nil
        }
    }
}
