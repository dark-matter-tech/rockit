// TraceabilityTests.swift
// RockitKit — Rockit Language Compiler
// Copyright © 2026 Dark Matter Tech. All rights reserved.

import XCTest
@testable import RockitKit

final class TraceabilityTests: XCTestCase {

    // MARK: - Helpers

    /// Parse + typecheck + lower to MIR, returning the module.
    private func lowerToMIR(_ source: String) -> MIRModule {
        let diagnostics = DiagnosticEngine()
        let lexer = Lexer(source: source, fileName: "test.rok", diagnostics: diagnostics)
        let tokens = lexer.tokenize()
        let parser = Parser(tokens: tokens, diagnostics: diagnostics)
        let ast = parser.parse()
        let checker = TypeChecker(ast: ast, diagnostics: diagnostics)
        let result = checker.check()
        XCTAssertFalse(diagnostics.hasErrors, "Frontend errors: \(diagnostics.errorCount)")
        let lowering = MIRLowering(typeCheckResult: result)
        return lowering.lower()
    }

    /// Full pipeline: source → MIR → LLVM IR text
    private func emitLLVM(_ source: String) -> String {
        let diagnostics = DiagnosticEngine()
        let lexer = Lexer(source: source, fileName: "test.rok", diagnostics: diagnostics)
        let tokens = lexer.tokenize()
        let parser = Parser(tokens: tokens, diagnostics: diagnostics)
        let ast = parser.parse()
        let checker = TypeChecker(ast: ast, diagnostics: diagnostics)
        let result = checker.check()
        XCTAssertFalse(diagnostics.hasErrors, "Frontend errors: \(diagnostics.errorCount)")
        let lowering = MIRLowering(typeCheckResult: result)
        let module = lowering.lower()
        let optimizer = MIROptimizer()
        let optimized = optimizer.optimize(module)
        let codeGen = LLVMCodeGen()
        return codeGen.emit(module: optimized)
    }

    // MARK: - MIR Source Map Tests

    func testSourceMapNonEmptyAfterLowering() {
        let module = lowerToMIR("""
        fun add(a: Int, b: Int): Int {
            val result = a + b
            return result
        }
        fun main(): Unit { println(add(1, 2)) }
        """)
        // The 'add' function should have source map entries
        let addFunc = module.functions.first { $0.name == "add" }
        XCTAssertNotNil(addFunc, "Should find 'add' function in MIR")
        XCTAssertFalse(addFunc!.sourceMap.entries.isEmpty,
            "Source map should have entries after lowering a multi-statement function")
    }

    func testSourceMapMultipleFunctions() {
        let module = lowerToMIR("""
        fun square(x: Int): Int { return x * x }
        fun double(x: Int): Int { return x + x }
        fun main(): Unit { println(square(3) + double(4)) }
        """)
        for func_ in module.functions {
            XCTAssertFalse(func_.sourceMap.entries.isEmpty,
                "Function '\(func_.name)' should have source map entries")
        }
    }

    func testSourceMapLookup() {
        let module = lowerToMIR("""
        fun main(): Unit {
            val x: Int = 42
            println(x)
        }
        """)
        let mainFunc = module.functions.first { $0.name == "main" }
        XCTAssertNotNil(mainFunc)
        // At least one instruction in the entry block should have a source mapping
        var foundMapping = false
        if let entry = mainFunc?.blocks.first {
            for i in 0..<entry.instructions.count {
                if mainFunc!.sourceMap.lookup(block: entry.label, index: i) != nil {
                    foundMapping = true
                    break
                }
            }
        }
        XCTAssertTrue(foundMapping, "Should find at least one source mapping in main's entry block")
    }

    func testSourceFileNamePropagated() {
        let module = lowerToMIR("fun main(): Unit { }")
        // sourceFileName should be set (from the AST's span)
        XCTAssertNotNil(module.sourceFileName)
    }

    // MARK: - LLVM Debug Metadata Tests

    func testLLVMIRContainsDISubprogram() {
        let ir = emitLLVM("""
        fun helper(): Unit { }
        fun main(): Unit { helper() }
        """)
        XCTAssertTrue(ir.contains("DISubprogram"), "LLVM IR should contain DISubprogram metadata")
        XCTAssertTrue(ir.contains("name: \"main\""), "Should have DISubprogram for main")
        XCTAssertTrue(ir.contains("name: \"helper\""), "Should have DISubprogram for helper")
    }

    func testLLVMIRContainsDILocation() {
        let ir = emitLLVM("""
        fun main(): Unit {
            val x: Int = 42
            println(x)
        }
        """)
        XCTAssertTrue(ir.contains("DILocation"), "LLVM IR should contain DILocation metadata")
    }

    func testLLVMIRContainsDbgAnnotations() {
        let ir = emitLLVM("""
        fun main(): Unit {
            val x: Int = 42
            println(x)
        }
        """)
        XCTAssertTrue(ir.contains("!dbg"), "LLVM IR instructions should have !dbg annotations")
    }

    func testDefineLineHasDbg() {
        let ir = emitLLVM("fun main(): Unit { }")
        // The define line should have !dbg
        for line in ir.split(separator: "\n") {
            if line.contains("define") && line.contains("@main") {
                XCTAssertTrue(line.contains("!dbg"), "define line should have !dbg: \(line)")
                break
            }
        }
    }

    func testDICompileUnitPresent() {
        let ir = emitLLVM("fun main(): Unit { }")
        XCTAssertTrue(ir.contains("DICompileUnit"), "Should have DICompileUnit metadata")
        XCTAssertTrue(ir.contains("DIFile"), "Should have DIFile metadata")
    }

    func testDISubroutineTypePresent() {
        let ir = emitLLVM("fun main(): Unit { }")
        XCTAssertTrue(ir.contains("DISubroutineType"), "Should have DISubroutineType metadata")
    }

    // MARK: - Version Header

    func testVersionInHeader() {
        let ir = emitLLVM("fun main(): Unit { }")
        XCTAssertTrue(ir.contains("0.1.0-alpha"), "LLVM IR header should include compiler version")
        XCTAssertTrue(ir.contains("Stage 0"), "LLVM IR header should identify Stage 0")
    }

    // MARK: - Determinism

    func testLLVMIRDeterministic() {
        let source = """
        fun add(a: Int, b: Int): Int { return a + b }
        fun main(): Unit { println(add(40, 2)) }
        """
        let ir1 = emitLLVM(source)
        let ir2 = emitLLVM(source)
        XCTAssertEqual(ir1, ir2, "Same source should produce identical LLVM IR")
    }
}
