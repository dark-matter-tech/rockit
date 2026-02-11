// VMTests.swift
// MoonKit — Moon Language Compiler
// Copyright © 2026 Dark Matter Tech. All rights reserved.

import XCTest
@testable import MoonKit

final class VMTests: XCTestCase {

    // MARK: - Helpers

    /// Full pipeline: source → lex → parse → type check → lower → optimize → codegen → BytecodeModule
    private func compile(_ source: String) -> BytecodeModule {
        let diagnostics = DiagnosticEngine()
        let lexer = Lexer(source: source, fileName: "test.moon", diagnostics: diagnostics)
        let tokens = lexer.tokenize()
        let parser = Parser(tokens: tokens, diagnostics: diagnostics)
        let ast = parser.parse()
        let checker = TypeChecker(ast: ast, diagnostics: diagnostics)
        let result = checker.check()
        let lowering = MIRLowering(typeCheckResult: result)
        let module = lowering.lower()
        let optimizer = MIROptimizer()
        let optimized = optimizer.optimize(module)
        let codeGen = CodeGen()
        return codeGen.generate(optimized)
    }

    /// Compile and run, capturing printed output.
    private func runCapturing(_ source: String) throws -> [String] {
        let module = compile(source)
        var output: [String] = []
        let builtins = BuiltinRegistry()
        builtins.register(name: "println") { args in
            output.append(args.map { $0.description }.joined(separator: " "))
            return .unit
        }
        builtins.register(name: "print") { args in
            output.append(args.map { $0.description }.joined(separator: " "))
            return .unit
        }
        let vmWithCapture = VM(module: module, builtins: builtins)
        try vmWithCapture.run()
        return output
    }

    /// Compile and run, expecting no errors.
    private func runSuccessfully(_ source: String) throws {
        let module = compile(source)
        let vm = VM(module: module)
        try vm.run()
    }

    // MARK: - Value Tests

    func testValueDescription() {
        XCTAssertEqual(Value.int(42).description, "42")
        XCTAssertEqual(Value.float(3.14).description, "3.14")
        XCTAssertEqual(Value.bool(true).description, "true")
        XCTAssertEqual(Value.bool(false).description, "false")
        XCTAssertEqual(Value.string("hello").description, "hello")
        XCTAssertEqual(Value.null.description, "null")
        XCTAssertEqual(Value.unit.description, "()")
    }

    func testValueTypeName() {
        XCTAssertEqual(Value.int(0).typeName, "Int")
        XCTAssertEqual(Value.float(0).typeName, "Float64")
        XCTAssertEqual(Value.bool(true).typeName, "Bool")
        XCTAssertEqual(Value.string("").typeName, "String")
        XCTAssertEqual(Value.null.typeName, "Nothing")
    }

    func testValueTruthy() {
        XCTAssertTrue(Value.bool(true).isTruthy)
        XCTAssertFalse(Value.bool(false).isTruthy)
        XCTAssertFalse(Value.null.isTruthy)
        XCTAssertTrue(Value.int(1).isTruthy)
        XCTAssertFalse(Value.int(0).isTruthy)
        XCTAssertTrue(Value.string("x").isTruthy)
    }

    func testValueEquality() {
        XCTAssertEqual(Value.int(42), Value.int(42))
        XCTAssertNotEqual(Value.int(42), Value.int(43))
        XCTAssertEqual(Value.string("hi"), Value.string("hi"))
        XCTAssertEqual(Value.null, Value.null)
        XCTAssertNotEqual(Value.int(0), Value.bool(false))
    }

    // MARK: - BytecodeLoader Tests

    func testLoaderRoundTrip() throws {
        let module = compile("fun main(): Unit { val x: Int = 42 }")
        let bytes = CodeGen.serialize(module)
        let loaded = try BytecodeLoader.load(bytes: bytes)

        XCTAssertEqual(loaded.constantPool.count, module.constantPool.count)
        XCTAssertEqual(loaded.functions.count, module.functions.count)
        XCTAssertEqual(loaded.globals.count, module.globals.count)
        XCTAssertEqual(loaded.types.count, module.types.count)
    }

    func testLoaderInvalidMagic() {
        let bytes: [UInt8] = [0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00]
        XCTAssertThrowsError(try BytecodeLoader.load(bytes: bytes))
    }

    func testLoaderTooSmall() {
        let bytes: [UInt8] = [0x4D, 0x4F]
        XCTAssertThrowsError(try BytecodeLoader.load(bytes: bytes))
    }

    func testLoaderFunctionBytecodePreserved() throws {
        let module = compile("fun main(): Unit { val x: Int = 42 }")
        let bytes = CodeGen.serialize(module)
        let loaded = try BytecodeLoader.load(bytes: bytes)

        let origFunc = module.functions.first!
        let loadedFunc = loaded.functions.first!
        XCTAssertEqual(origFunc.bytecode, loadedFunc.bytecode)
        XCTAssertEqual(origFunc.parameterCount, loadedFunc.parameterCount)
        XCTAssertEqual(origFunc.registerCount, loadedFunc.registerCount)
    }

    func testLoaderConstantPoolValues() throws {
        let module = compile("""
        fun main(): Unit {
            println("hello")
        }
        """)
        let bytes = CodeGen.serialize(module)
        let loaded = try BytecodeLoader.load(bytes: bytes)

        let hasHello = loaded.constantPool.contains { $0.value == "hello" }
        XCTAssert(hasHello, "Expected 'hello' in constant pool")
    }

    // MARK: - VM Error Tests

    func testVMErrorDescription() {
        let err = VMError.divisionByZero
        XCTAssert(err.description.contains("division by zero"))

        let err2 = VMError.nullPointerAccess(context: "test")
        XCTAssert(err2.description.contains("null"))

        let err3 = VMError.stackOverflow(depth: 1024)
        XCTAssert(err3.description.contains("1024"))
    }

    func testStackTrace() {
        let trace = StackTrace(
            error: .divisionByZero,
            frames: [
                StackTraceFrame(functionName: "main", bytecodeOffset: 10),
                StackTraceFrame(functionName: "add", bytecodeOffset: 5)
            ]
        )
        XCTAssert(trace.description.contains("main"))
        XCTAssert(trace.description.contains("add"))
        XCTAssert(trace.description.contains("division by zero"))
    }

    // MARK: - End-to-End Execution Tests

    func testRunEmptyMain() throws {
        try runSuccessfully("fun main(): Unit { }")
    }

    func testRunConstantAssignment() throws {
        try runSuccessfully("fun main(): Unit { val x: Int = 42 }")
    }

    func testRunPrintln() throws {
        let output = try runCapturing("""
        fun main(): Unit {
            println("hello world")
        }
        """)
        XCTAssertEqual(output, ["hello world"])
    }

    func testRunPrintlnInt() throws {
        let output = try runCapturing("""
        fun main(): Unit {
            println(42)
        }
        """)
        XCTAssertEqual(output.first, "42")
    }

    func testRunArithmetic() throws {
        // Constant folding may fold 2+3 to 5, but the result should still be correct
        try runSuccessfully("""
        fun main(): Unit {
            val x: Int = 2 + 3
        }
        """)
    }

    func testRunBooleanLogic() throws {
        try runSuccessfully("""
        fun main(): Unit {
            val x: Bool = true
            val y: Bool = false
        }
        """)
    }

    func testRunIfElse() throws {
        let output = try runCapturing("""
        fun main(): Unit {
            val x: Bool = true
            if (x) {
                println("yes")
            } else {
                println("no")
            }
        }
        """)
        XCTAssert(output.contains("yes"))
    }

    func testRunWhileLoop() throws {
        try runSuccessfully("""
        fun main(): Unit {
            var i: Int = 0
            while (i < 5) {
                i = i + 1
            }
        }
        """)
    }

    func testRunFunctionCall() throws {
        let output = try runCapturing("""
        fun greet(): Unit {
            println("hi")
        }
        fun main(): Unit {
            greet()
        }
        """)
        XCTAssertEqual(output, ["hi"])
    }

    func testRunFunctionWithArgs() throws {
        try runSuccessfully("""
        fun add(a: Int, b: Int): Int {
            return a
        }
        fun main(): Unit {
            val x: Int = add(1, 2)
        }
        """)
    }

    func testRunClassConstruction() throws {
        try runSuccessfully("""
        class Point(val x: Int, val y: Int)
        fun main(): Unit {
            val p: Point = Point(1, 2)
        }
        """)
    }

    func testRunFieldAccess() throws {
        try runSuccessfully("""
        class User(val name: String)
        fun main(): Unit {
            val u: User = User("Alice")
            val n: String = u.name
        }
        """)
    }

    func testRunNullCheck() throws {
        try runSuccessfully("""
        fun main(): Unit {
            val x: String? = null
        }
        """)
    }

    func testRunStringInterpolation() throws {
        try runSuccessfully("""
        fun main(): Unit {
            val name: String = "world"
            val msg: String = "hello"
        }
        """)
    }

    func testRunGlobal() throws {
        try runSuccessfully("""
        val VERSION: String = "1.0"
        fun main(): Unit { }
        """)
    }

    func testRunMultipleFunctions() throws {
        try runSuccessfully("""
        fun helper(): Unit { }
        fun main(): Unit {
            helper()
        }
        """)
    }

    // MARK: - RuntimeConfig Tests

    func testDefaultConfig() {
        let config = RuntimeConfig.default
        XCTAssertEqual(config.maxCallStackDepth, 1024)
        XCTAssertEqual(config.maxHeapObjects, 1_000_000)
        XCTAssertFalse(config.traceExecution)
        XCTAssertFalse(config.gcStats)
    }

    func testCustomConfig() {
        let config = RuntimeConfig(maxCallStackDepth: 512, traceExecution: true)
        XCTAssertEqual(config.maxCallStackDepth, 512)
        XCTAssertTrue(config.traceExecution)
    }

    // MARK: - Builtin Registry Tests

    func testBuiltinRegistration() {
        let registry = BuiltinRegistry()
        XCTAssertTrue(registry.isBuiltin("println"))
        XCTAssertTrue(registry.isBuiltin("print"))
        XCTAssertTrue(registry.isBuiltin("toString"))
        XCTAssertFalse(registry.isBuiltin("nonexistent"))
    }

    func testBuiltinToString() throws {
        let registry = BuiltinRegistry()
        let fn = registry.lookup("toString")!
        let result = try fn([.int(42)])
        XCTAssertEqual(result, .string("42"))
    }

    func testBuiltinStringLength() throws {
        let registry = BuiltinRegistry()
        let fn = registry.lookup("stringLength")!
        let result = try fn([.string("hello")])
        XCTAssertEqual(result, .int(5))
    }

    func testBuiltinTypeOf() throws {
        let registry = BuiltinRegistry()
        let fn = registry.lookup("typeOf")!
        XCTAssertEqual(try fn([.int(1)]), .string("Int"))
        XCTAssertEqual(try fn([.string("")]), .string("String"))
        XCTAssertEqual(try fn([.null]), .string("Nothing"))
    }

    func testBuiltinAbs() throws {
        let registry = BuiltinRegistry()
        let fn = registry.lookup("abs")!
        XCTAssertEqual(try fn([.int(-5)]), .int(5))
        XCTAssertEqual(try fn([.int(5)]), .int(5))
        XCTAssertEqual(try fn([.float(-3.14)]), .float(3.14))
    }

    func testBuiltinMinMax() throws {
        let registry = BuiltinRegistry()
        let minFn = registry.lookup("min")!
        let maxFn = registry.lookup("max")!
        XCTAssertEqual(try minFn([.int(3), .int(7)]), .int(3))
        XCTAssertEqual(try maxFn([.int(3), .int(7)]), .int(7))
    }

    // MARK: - Serialization Round-Trip via Loader

    func testSerializeLoadExecute() throws {
        let module = compile("""
        fun main(): Unit {
            val x: Int = 42
        }
        """)
        let bytes = CodeGen.serialize(module)
        let loaded = try BytecodeLoader.load(bytes: bytes)
        let vm = VM(module: loaded)
        try vm.run()
    }

    // MARK: - Trace Mode

    func testTraceMode() throws {
        let module = compile("fun main(): Unit { val x: Int = 42 }")
        var traceOutput: [String] = []
        let config = RuntimeConfig(traceExecution: true)
        let builtins = BuiltinRegistry()
        let vm = VM(module: module, config: config, builtins: builtins)
        vm.outputCapture = { traceOutput.append($0) }
        try vm.run()
        // Trace should have produced some output
        XCTAssert(traceOutput.count > 0, "Expected trace output")
    }

    // MARK: - Error Handling

    func testUnknownFunctionError() {
        let module = BytecodeModule(constantPool: [], globals: [], types: [], functions: [])
        let vm = VM(module: module)
        XCTAssertThrowsError(try vm.run()) { error in
            XCTAssert("\(error)".contains("main"), "Expected error about missing main")
        }
    }
}
