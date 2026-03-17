// SafetyVerifierTests.swift
// RockitKit — Rockit Language Compiler
// Copyright © 2026 Dark Matter Tech. All rights reserved.

import XCTest
@testable import RockitKit

final class SafetyVerifierTests: XCTestCase {

    // MARK: - Helpers

    private func verify(_ source: String, level: SafetyLevel) -> SafetyVerificationResult {
        let diagnostics = DiagnosticEngine()
        let lexer = Lexer(source: source, fileName: "test.rok", diagnostics: diagnostics)
        let tokens = lexer.tokenize()
        let parser = Parser(tokens: tokens, diagnostics: diagnostics)
        let ast = parser.parse()
        let checker = TypeChecker(ast: ast, diagnostics: diagnostics)
        let result = checker.check()
        let verifyDiag = DiagnosticEngine()
        let verifier = SafetyVerifier(level: level, ast: result.ast, diagnostics: verifyDiag)
        return verifier.verify()
    }

    private func categories(_ result: SafetyVerificationResult) -> Set<SafetyViolationCategory> {
        Set(result.violations.map { $0.category })
    }

    // MARK: - DAL A (most restrictive)

    func testDALA_BlocksRecursion() {
        let result = verify("""
        fun fib(n: Int): Int {
            if (n <= 1) { return n }
            return fib(n - 1) + fib(n - 2)
        }
        fun main(): Unit { println(fib(10)) }
        """, level: .dalA)
        XCTAssertFalse(result.passed)
        XCTAssertTrue(categories(result).contains(.unboundedRecursion))
    }

    func testDALA_BlocksUnboundedLoop() {
        let result = verify("""
        fun main(): Unit {
            var x: Int = 1
            while (true) { x = x + 1 }
        }
        """, level: .dalA)
        XCTAssertFalse(result.passed)
        XCTAssertTrue(categories(result).contains(.unboundedLoop))
    }

    func testDALA_AllowsBoundedLoop() {
        let result = verify("""
        fun main(): Unit {
            var i: Int = 0
            while (i < 10) { i = i + 1 }
        }
        """, level: .dalA)
        // Should not have unboundedLoop violation (other violations may exist)
        XCTAssertFalse(categories(result).contains(.unboundedLoop))
    }

    func testDALA_BlocksDynamicAllocation() {
        let result = verify("""
        fun main(): Unit {
            val xs = listCreate()
        }
        """, level: .dalA)
        XCTAssertFalse(result.passed)
        XCTAssertTrue(categories(result).contains(.dynamicAllocation))
    }

    func testDALA_BlocksExceptions() {
        let result = verify("""
        fun main(): Unit {
            throw "error"
        }
        """, level: .dalA)
        XCTAssertFalse(result.passed)
        XCTAssertTrue(categories(result).contains(.exceptionHandling))
    }

    func testDALA_BlocksLambdas() {
        let result = verify("""
        fun main(): Unit {
            val f = { x: Int -> x + 1 }
        }
        """, level: .dalA)
        XCTAssertFalse(result.passed)
        XCTAssertTrue(categories(result).contains(.closureCapture))
    }

    func testDALA_BlocksAsyncAwait() {
        let result = verify("""
        suspend fun fetch(): Int { return 42 }
        fun main(): Unit {
            val x = await fetch()
        }
        """, level: .dalA)
        XCTAssertFalse(result.passed)
        XCTAssertTrue(categories(result).contains(.asyncExecution))
    }

    func testDALA_BlocksStringInterpolation() {
        let result = verify("""
        fun main(): Unit {
            val name = "world"
            val msg = "hello ${name}"
        }
        """, level: .dalA)
        XCTAssertFalse(result.passed)
        XCTAssertTrue(categories(result).contains(.dynamicStringOp))
    }

    func testDALA_BlocksHeapConstruction() {
        let result = verify("""
        class Point(val x: Int, val y: Int)
        fun main(): Unit {
            val p = Point(1, 2)
        }
        """, level: .dalA)
        XCTAssertFalse(result.passed)
        XCTAssertTrue(categories(result).contains(.heapObjectConstruction))
    }

    // MARK: - DAL B

    func testDALB_BlocksRecursion() {
        let result = verify("""
        fun rec(n: Int): Int { return rec(n - 1) }
        fun main(): Unit { println(rec(5)) }
        """, level: .dalB)
        XCTAssertTrue(categories(result).contains(.unboundedRecursion))
    }

    func testDALB_BlocksExceptions() {
        let result = verify("""
        fun main(): Unit { throw "err" }
        """, level: .dalB)
        XCTAssertTrue(categories(result).contains(.exceptionHandling))
    }

    func testDALB_BlocksLambdas() {
        let result = verify("""
        fun main(): Unit { val f = { x: Int -> x } }
        """, level: .dalB)
        XCTAssertTrue(categories(result).contains(.closureCapture))
    }

    func testDALB_BlocksAsyncAwait() {
        let result = verify("""
        suspend fun f(): Int { return 1 }
        fun main(): Unit { val x = await f() }
        """, level: .dalB)
        XCTAssertTrue(categories(result).contains(.asyncExecution))
    }

    // MARK: - DAL C (allows exceptions and closures, blocks async)

    func testDALC_AllowsExceptions() {
        let result = verify("""
        fun main(): Unit { throw "err" }
        """, level: .dalC)
        XCTAssertFalse(categories(result).contains(.exceptionHandling))
    }

    func testDALC_AllowsLambdas() {
        let result = verify("""
        fun main(): Unit { val f = { x: Int -> x } }
        """, level: .dalC)
        XCTAssertFalse(categories(result).contains(.closureCapture))
    }

    func testDALC_BlocksAsyncAwait() {
        let result = verify("""
        suspend fun f(): Int { return 1 }
        fun main(): Unit { val x = await f() }
        """, level: .dalC)
        XCTAssertTrue(categories(result).contains(.asyncExecution))
    }

    func testDALC_BlocksRecursion() {
        let result = verify("""
        fun rec(n: Int): Int { return rec(n - 1) }
        fun main(): Unit { println(rec(5)) }
        """, level: .dalC)
        XCTAssertTrue(categories(result).contains(.unboundedRecursion))
    }

    func testDALC_BlocksUnboundedLoop() {
        let result = verify("""
        fun main(): Unit { while (true) { } }
        """, level: .dalC)
        XCTAssertTrue(categories(result).contains(.unboundedLoop))
    }

    // MARK: - DAL D (allows async, blocks recursion and unbounded loops)

    func testDALD_AllowsAsyncAwait() {
        let result = verify("""
        suspend fun f(): Int { return 1 }
        fun main(): Unit { val x = await f() }
        """, level: .dalD)
        XCTAssertFalse(categories(result).contains(.asyncExecution))
    }

    func testDALD_BlocksRecursion() {
        let result = verify("""
        fun rec(n: Int): Int { return rec(n - 1) }
        fun main(): Unit { println(rec(5)) }
        """, level: .dalD)
        XCTAssertTrue(categories(result).contains(.unboundedRecursion))
    }

    func testDALD_BlocksUnboundedLoop() {
        let result = verify("""
        fun main(): Unit { while (true) { } }
        """, level: .dalD)
        XCTAssertTrue(categories(result).contains(.unboundedLoop))
    }

    // MARK: - DAL E (least restrictive — allows everything)

    func testDALE_AllowsRecursion() {
        let result = verify("""
        fun rec(n: Int): Int { return rec(n - 1) }
        fun main(): Unit { println(rec(5)) }
        """, level: .dalE)
        XCTAssertFalse(categories(result).contains(.unboundedRecursion))
    }

    func testDALE_AllowsUnboundedLoop() {
        let result = verify("""
        fun main(): Unit { while (true) { } }
        """, level: .dalE)
        XCTAssertFalse(categories(result).contains(.unboundedLoop))
    }

    func testDALE_AllowsExceptions() {
        let result = verify("""
        fun main(): Unit { throw "err" }
        """, level: .dalE)
        XCTAssertTrue(result.passed)
    }

    func testDALE_AllowsLambdas() {
        let result = verify("""
        fun main(): Unit { val f = { x: Int -> x } }
        """, level: .dalE)
        XCTAssertTrue(result.passed)
    }

    func testDALE_AllowsAsyncAwait() {
        let result = verify("""
        suspend fun f(): Int { return 1 }
        fun main(): Unit { val x = await f() }
        """, level: .dalE)
        XCTAssertTrue(result.passed)
    }

    // MARK: - Violation JSON

    func testViolationToJSON() {
        let span = SourceSpan(
            start: SourceLocation(file: "test.rok", line: 5, column: 3),
            end: SourceLocation(file: "test.rok", line: 5, column: 10)
        )
        let violation = SafetyViolation(
            category: .dynamicAllocation,
            message: "listCreate allocates on heap",
            span: span,
            functionName: "main"
        )
        let json = violation.toJSON()
        XCTAssertEqual(json["code"] as? String, "MEM-001")
        XCTAssertEqual(json["function"] as? String, "main")
        XCTAssertNotNil(json["rationale"])
        XCTAssertNotNil(json["compliantAlternative"])
        let loc = json["location"] as! [String: Any]
        XCTAssertEqual(loc["line"] as? Int, 5)
    }

    // MARK: - Rationale Properties

    func testAllCategoriesHaveRationale() {
        let categories: [SafetyViolationCategory] = [
            .unboundedRecursion, .dynamicAllocation, .closureCapture,
            .exceptionHandling, .unboundedLoop, .dynamicStringOp,
            .asyncExecution, .heapObjectConstruction,
        ]
        for cat in categories {
            XCTAssertFalse(cat.rationale.isEmpty, "\(cat.rawValue) should have rationale")
            XCTAssertFalse(cat.compliantAlternative.isEmpty, "\(cat.rawValue) should have compliant alternative")
        }
    }

    func testRationaleUsesARCTerminology() {
        // Ensure ARC-specific terms appear, not GC terms
        let allocRationale = SafetyViolationCategory.dynamicAllocation.rationale
        XCTAssertTrue(allocRationale.contains("ARC") || allocRationale.contains("retain/release"),
            "Dynamic allocation rationale should reference ARC concepts")
    }

    // MARK: - Verification Result JSON

    func testVerificationResultToJSON() {
        let result = SafetyVerificationResult(
            level: .dalA,
            violations: [],
            callGraph: ["main": Set(["helper"])]
        )
        let json = result.toJSON()
        XCTAssertEqual(json["level"] as? String, "dal-a")
        XCTAssertEqual(json["passed"] as? Bool, true)
        XCTAssertEqual(json["violationCount"] as? Int, 0)
    }
}
