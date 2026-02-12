// main.swift
// RockitCLI — Rockit Language Compiler
// Copyright © 2026 Dark Matter Tech. All rights reserved.

import Foundation
import RockitKit

let version = "0.1.0-alpha"

func printUsage() {
    print("""
    rockit \(version) — Rockit Language Compiler
    Dark Matter Tech

    USAGE:
        rockit <subcommand> [options] <file>

    COMMANDS:
        run <file>            Execute a .rok or .rokb file
        build <file.rok>      Compile to bytecode (.rokb)
        build-native <file>   Compile to native executable via LLVM
        run-native <file>     Compile to native and execute
        emit-llvm <file>      Emit LLVM IR (.ll) for inspection
        launch                Start interactive REPL
        init [name]           Create a new Rockit project
        test [file]           Run tests
        lex <file.rok>        Tokenize and dump tokens
        parse <file.rok>      Parse and dump AST
        check <file.rok>      Type-check and report diagnostics
        lower <file.rok>      Lower to MIR and dump
        version               Print version

    OPTIONS:
        --dump-tokens         Show token stream (with lex)
        --dump-ast            Show AST (with parse)
        --dump-types          Show inferred types (with check)
        --dump-mir            Show optimized MIR (with lower)
        --dump-mir-unoptimized Show MIR before optimization
        --dump-bytecode       Show disassembled bytecode (with build)
        --dump-llvm           Show LLVM IR (with build-native)
        --trace               Show instruction-level execution trace (with run)
        --gc-stats            Show ARC/memory statistics (with run)
        --no-color            Disable colored output
    """)
}

func lex(file: String, dumpTokens: Bool) {
    guard FileManager.default.fileExists(atPath: file) else {
        print("error: file not found: \(file)")
        exit(1)
    }

    guard let source = try? String(contentsOfFile: file, encoding: .utf8) else {
        print("error: could not read file: \(file)")
        exit(1)
    }

    let diagnostics = DiagnosticEngine()
    let lexer = Lexer(source: source, fileName: file, diagnostics: diagnostics)
    let tokens = lexer.tokenize()

    if dumpTokens {
        let nonNewline = tokens.filter { $0.kind != .newline }
        let maxLexemeLen = nonNewline.map { $0.lexeme.count }.max() ?? 0
        let padLen = min(max(maxLexemeLen, 10), 30)

        for token in tokens {
            if token.kind == .newline { continue }
            if token.kind == .eof {
                print("  EOF")
                break
            }

            let loc = "\(token.span.start.line):\(token.span.start.column)"
            let padLoc = loc.padding(toLength: 8, withPad: " ", startingAt: 0)
            let padLex = token.lexeme.padding(toLength: padLen, withPad: " ", startingAt: 0)

            print("  \(padLoc) \(padLex) \(token.kind)")
        }
    }

    // Summary
    let tokenCount = tokens.filter { $0.kind != .newline && $0.kind != .eof }.count
    print("\n\(file): \(tokenCount) tokens")

    if diagnostics.hasErrors {
        diagnostics.dump()
        print("\n\(diagnostics.errorCount) error(s)")
        exit(1)
    } else {
        print("OK")
    }
}

func parseCommand(file: String, dumpAST: Bool) {
    guard FileManager.default.fileExists(atPath: file) else {
        print("error: file not found: \(file)")
        exit(1)
    }

    guard let source = try? String(contentsOfFile: file, encoding: .utf8) else {
        print("error: could not read file: \(file)")
        exit(1)
    }

    let diagnostics = DiagnosticEngine()
    let lexer = Lexer(source: source, fileName: file, diagnostics: diagnostics)
    let tokens = lexer.tokenize()
    let parser = Parser(tokens: tokens, diagnostics: diagnostics)
    let ast = parser.parse()

    if dumpAST {
        print(ast.dump())
    }

    let declCount = ast.declarations.count
    print("\n\(file): \(declCount) declaration(s)")

    if diagnostics.hasErrors {
        diagnostics.dump()
        print("\n\(diagnostics.errorCount) error(s)")
        exit(1)
    } else {
        print("OK")
    }
}

func checkCommand(file: String, dumpTypes: Bool) {
    guard FileManager.default.fileExists(atPath: file) else {
        print("error: file not found: \(file)")
        exit(1)
    }

    guard let source = try? String(contentsOfFile: file, encoding: .utf8) else {
        print("error: could not read file: \(file)")
        exit(1)
    }

    let diagnostics = DiagnosticEngine()
    let lexer = Lexer(source: source, fileName: file, diagnostics: diagnostics)
    let tokens = lexer.tokenize()
    let parser = Parser(tokens: tokens, diagnostics: diagnostics)
    let ast = parser.parse()

    let checker = TypeChecker(ast: ast, diagnostics: diagnostics)
    let result = checker.check()

    if dumpTypes {
        print("--- Inferred Types ---")
        for (id, type) in result.typeMap.sorted(by: { ($0.key.line, $0.key.column) < ($1.key.line, $1.key.column) }) {
            print("  \(id.line):\(id.column)  \(type)")
        }
        print("--- End Types ---")
    }

    let declCount = ast.declarations.count
    let typeCount = result.typeMap.count
    print("\n\(file): \(declCount) declaration(s), \(typeCount) type(s) inferred")

    if diagnostics.hasErrors {
        diagnostics.dump()
        print("\n\(diagnostics.errorCount) error(s)")
        exit(1)
    } else {
        print("OK")
    }
}

func lowerCommand(file: String, dumpMIR: Bool, dumpUnoptimized: Bool = false) {
    guard FileManager.default.fileExists(atPath: file) else {
        print("error: file not found: \(file)")
        exit(1)
    }

    guard let source = try? String(contentsOfFile: file, encoding: .utf8) else {
        print("error: could not read file: \(file)")
        exit(1)
    }

    let diagnostics = DiagnosticEngine()
    let lexer = Lexer(source: source, fileName: file, diagnostics: diagnostics)
    let tokens = lexer.tokenize()
    let parser = Parser(tokens: tokens, diagnostics: diagnostics)
    let ast = parser.parse()

    let checker = TypeChecker(ast: ast, diagnostics: diagnostics)
    let typeResult = checker.check()

    let lowering = MIRLowering(typeCheckResult: typeResult)
    let unoptimized = lowering.lower()

    if dumpUnoptimized {
        print("--- Unoptimized MIR ---")
        print(unoptimized)
        print("--- End Unoptimized MIR ---")
    }

    let optimizer = MIROptimizer()
    let module = optimizer.optimize(unoptimized)

    if dumpMIR {
        print(module)
    }

    let funcCount = module.functions.count
    let instrCount = module.totalInstructionCount
    let typeCount = module.types.count
    let globalCount = module.globals.count
    let savedInstrs = unoptimized.totalInstructionCount - instrCount
    let savedFuncs = unoptimized.functions.count - funcCount
    print("\n\(file): \(funcCount) function(s), \(instrCount) instruction(s), \(typeCount) type(s), \(globalCount) global(s)")
    if savedInstrs > 0 || savedFuncs > 0 {
        print("  optimized: \(savedInstrs) instruction(s) eliminated, \(savedFuncs) function(s) removed")
    }

    if diagnostics.hasErrors {
        diagnostics.dump()
        print("\n\(diagnostics.errorCount) error(s)")
        exit(1)
    } else {
        print("OK")
    }
}

func buildCommand(file: String, dumpBytecode: Bool) {
    guard FileManager.default.fileExists(atPath: file) else {
        print("error: file not found: \(file)")
        exit(1)
    }

    guard let source = try? String(contentsOfFile: file, encoding: .utf8) else {
        print("error: could not read file: \(file)")
        exit(1)
    }

    let diagnostics = DiagnosticEngine()
    let lexer = Lexer(source: source, fileName: file, diagnostics: diagnostics)
    let tokens = lexer.tokenize()
    let parser = Parser(tokens: tokens, diagnostics: diagnostics)
    let ast = parser.parse()

    let checker = TypeChecker(ast: ast, diagnostics: diagnostics)
    let typeResult = checker.check()

    if diagnostics.hasErrors {
        diagnostics.dump()
        print("\n\(diagnostics.errorCount) error(s)")
        exit(1)
    }

    let lowering = MIRLowering(typeCheckResult: typeResult)
    let unoptimized = lowering.lower()
    let optimizer = MIROptimizer()
    let optimized = optimizer.optimize(unoptimized)

    let codeGen = CodeGen()
    let bytecodeModule = codeGen.generate(optimized)

    if dumpBytecode {
        print(CodeGen.disassemble(bytecodeModule))
    }

    // Serialize to .rokb
    let outputPath = file.hasSuffix(".rok")
        ? String(file.dropLast(4)) + ".rokb"
        : file + ".rokb"

    let bytes = CodeGen.serialize(bytecodeModule)
    let data = Data(bytes)
    do {
        try data.write(to: URL(fileURLWithPath: outputPath))
    } catch {
        print("error: could not write output file: \(outputPath)")
        exit(1)
    }

    let funcCount = bytecodeModule.functions.count
    let bytecodeSize = bytecodeModule.totalBytecodeSize
    let totalSize = bytes.count
    print("\n\(file) \u{2192} \(outputPath)")
    print("  \(funcCount) function(s), \(bytecodeSize) bytes bytecode, \(totalSize) bytes total")
    print("OK")
}

func runCommand(file: String, trace: Bool, gcStats: Bool) {
    guard FileManager.default.fileExists(atPath: file) else {
        print("error: file not found: \(file)")
        exit(1)
    }

    let module: BytecodeModule

    if file.hasSuffix(".rokb") {
        // Load pre-compiled bytecode
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: file)) else {
            print("error: could not read file: \(file)")
            exit(1)
        }
        do {
            module = try BytecodeLoader.load(bytes: Array(data))
        } catch {
            print("error: \(error)")
            exit(1)
        }
    } else {
        // Compile from source first
        guard let source = try? String(contentsOfFile: file, encoding: .utf8) else {
            print("error: could not read file: \(file)")
            exit(1)
        }

        let diagnostics = DiagnosticEngine()
        let lexer = Lexer(source: source, fileName: file, diagnostics: diagnostics)
        let tokens = lexer.tokenize()
        let parser = Parser(tokens: tokens, diagnostics: diagnostics)
        let ast = parser.parse()

        let checker = TypeChecker(ast: ast, diagnostics: diagnostics)
        let typeResult = checker.check()

        if diagnostics.hasErrors {
            diagnostics.dump()
            print("\n\(diagnostics.errorCount) error(s)")
            exit(1)
        }

        let lowering = MIRLowering(typeCheckResult: typeResult)
        let unoptimized = lowering.lower()
        let optimizer = MIROptimizer()
        let optimized = optimizer.optimize(unoptimized)
        let codeGen = CodeGen()
        module = codeGen.generate(optimized)
    }

    let config = RuntimeConfig(traceExecution: trace, gcStats: gcStats)
    let vm = VM(module: module, config: config)

    do {
        try vm.run()
        if gcStats {
            vm.printGCStats()
        }
    } catch {
        let stackTrace = vm.captureStackTrace(error: error as! VMError)
        print(stackTrace)
        exit(1)
    }
}

// MARK: - REPL

func replCommand() {
    print("Rockit REPL v\(version)")
    print("Type expressions or statements. Type :quit to exit.\n")

    // Accumulate top-level declarations (fun, class, etc.)
    var topDecls = ""
    // Accumulate statements that go inside main (val/var decls, etc.)
    var mainBody = ""

    while true {
        print("rockit> ", terminator: "")
        guard let line = readLine() else { break }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { continue }
        if trimmed == ":quit" || trimmed == ":q" { break }
        if trimmed == ":reset" { topDecls = ""; mainBody = ""; print("State cleared."); continue }

        // Check if this is a top-level declaration (fun, class, etc.)
        let isTopDecl = trimmed.hasPrefix("fun ") || trimmed.hasPrefix("class ") ||
                        trimmed.hasPrefix("data ") || trimmed.hasPrefix("sealed ") ||
                        trimmed.hasPrefix("enum ") || trimmed.hasPrefix("interface ") ||
                        trimmed.hasPrefix("object ")

        // Multi-line support: if line has unmatched braces, keep reading
        var fullInput = line
        var braceCount = 0
        for ch in fullInput { if ch == "{" { braceCount += 1 } else if ch == "}" { braceCount -= 1 } }
        while braceCount > 0 {
            print("  ... ", terminator: "")
            guard let continuation = readLine() else { break }
            fullInput += "\n" + continuation
            for ch in continuation { if ch == "{" { braceCount += 1 } else if ch == "}" { braceCount -= 1 } }
        }

        let isValVar = trimmed.hasPrefix("val ") || trimmed.hasPrefix("var ")

        // Determine if this looks like a statement keyword (not an expression)
        let isStatement = trimmed.hasPrefix("println(") || trimmed.hasPrefix("print(") ||
                          trimmed.hasPrefix("if ") || trimmed.hasPrefix("if(") ||
                          trimmed.hasPrefix("while ") || trimmed.hasPrefix("while(") ||
                          trimmed.hasPrefix("for ") || trimmed.hasPrefix("for(") ||
                          trimmed.hasPrefix("return ") || trimmed.hasPrefix("return\n") ||
                          trimmed == "return"

        if isTopDecl {
            // Add declaration to top-level preamble
            topDecls += fullInput + "\n\n"
            let source = topDecls + "fun main(): Unit {\n\(mainBody)}\n"
            let diagnostics = DiagnosticEngine()
            let lexer = Lexer(source: source, fileName: "<repl>", diagnostics: diagnostics)
            let tokens = lexer.tokenize()
            let parser = Parser(tokens: tokens, diagnostics: diagnostics)
            let ast = parser.parse()
            let checker = TypeChecker(ast: ast, diagnostics: diagnostics)
            _ = checker.check()
            if diagnostics.hasErrors {
                diagnostics.dump()
                // Undo the addition
                topDecls = String(topDecls.dropLast(fullInput.count + 2))
            } else {
                print("OK")
            }
            continue
        }

        if isValVar {
            // Accumulate val/var in main body
            let newBody = mainBody + "  " + fullInput + "\n"
            let source = topDecls + "fun main(): Unit {\n\(newBody)}\n"
            let diagnostics = DiagnosticEngine()
            let lexer = Lexer(source: source, fileName: "<repl>", diagnostics: diagnostics)
            let tokens = lexer.tokenize()
            let parser = Parser(tokens: tokens, diagnostics: diagnostics)
            let ast = parser.parse()
            let checker = TypeChecker(ast: ast, diagnostics: diagnostics)
            _ = checker.check()
            if diagnostics.hasErrors {
                diagnostics.dump()
            } else {
                mainBody = newBody
            }
            continue
        }

        // For non-statement expressions, try auto-printing first
        if !isStatement {
            let exprSource = topDecls + "fun main(): Unit {\n\(mainBody)  println(toString(\(fullInput)))\n}\n"
            let exprDiag = DiagnosticEngine()
            let exprLexer = Lexer(source: exprSource, fileName: "<repl>", diagnostics: exprDiag)
            let exprTokens = exprLexer.tokenize()
            let exprParser = Parser(tokens: exprTokens, diagnostics: exprDiag)
            let exprAST = exprParser.parse()
            let exprChecker = TypeChecker(ast: exprAST, diagnostics: exprDiag)
            let exprResult = exprChecker.check()

            if !exprDiag.hasErrors {
                let lowering = MIRLowering(typeCheckResult: exprResult)
                let mir = lowering.lower()
                let optimizer = MIROptimizer()
                let optimized = optimizer.optimize(mir)
                let codeGen = CodeGen()
                let module = codeGen.generate(optimized)
                let vm = VM(module: module, config: RuntimeConfig())
                do { try vm.run() } catch {
                    let st = vm.captureStackTrace(error: error as! VMError)
                    print(st)
                }
                continue
            }
        }

        // Fall back to statement compilation
        let source = topDecls + "fun main(): Unit {\n\(mainBody)  \(fullInput)\n}\n"
        let diagnostics = DiagnosticEngine()
        let lexer = Lexer(source: source, fileName: "<repl>", diagnostics: diagnostics)
        let tokens = lexer.tokenize()
        let parser = Parser(tokens: tokens, diagnostics: diagnostics)
        let ast = parser.parse()
        let checker = TypeChecker(ast: ast, diagnostics: diagnostics)
        let typeResult = checker.check()

        if diagnostics.hasErrors {
            diagnostics.dump()
            continue
        }

        let lowering = MIRLowering(typeCheckResult: typeResult)
        let mir = lowering.lower()
        let optimizer = MIROptimizer()
        let optimized = optimizer.optimize(mir)
        let codeGen = CodeGen()
        let module = codeGen.generate(optimized)
        let vm = VM(module: module, config: RuntimeConfig())
        do { try vm.run() } catch {
            let st = vm.captureStackTrace(error: error as! VMError)
            print(st)
        }
    }
}

// MARK: - Init Command

func initCommand(name: String) {
    let fm = FileManager.default
    let projectDir = fm.currentDirectoryPath + "/" + name

    guard !fm.fileExists(atPath: projectDir) else {
        print("error: directory '\(name)' already exists")
        exit(1)
    }

    do {
        try fm.createDirectory(atPath: projectDir + "/src", withIntermediateDirectories: true)
        try fm.createDirectory(atPath: projectDir + "/tests", withIntermediateDirectories: true)

        // fuel.toml
        let fuelToml = """
        [package]
        name = "\(name)"
        version = "0.1.0"

        [dependencies]
        """
        try fuelToml.write(toFile: projectDir + "/fuel.toml", atomically: true, encoding: .utf8)

        // src/main.rok
        let mainRok = """
        fun main(): Unit {
            println("Hello, Rockit!")
        }
        """
        try mainRok.write(toFile: projectDir + "/src/main.rok", atomically: true, encoding: .utf8)

        // tests/test_main.rok
        let testRok = """
        fun test_hello(): Unit {
            val expected = "Hello, Rockit!"
            println("PASS: test_hello")
        }

        fun main(): Unit {
            test_hello()
        }
        """
        try testRok.write(toFile: projectDir + "/tests/test_main.rok", atomically: true, encoding: .utf8)

        print("Created new Rockit project '\(name)'")
        print("  \(name)/fuel.toml")
        print("  \(name)/src/main.rok")
        print("  \(name)/tests/test_main.rok")
        print("\nGet started:")
        print("  cd \(name)")
        print("  rockit run src/main.rok")
    } catch {
        print("error: could not create project: \(error)")
        exit(1)
    }
}

// MARK: - Test Command

func testCommand(file: String?) {
    let fm = FileManager.default

    var testFiles: [String] = []

    if let file = file {
        guard fm.fileExists(atPath: file) else {
            print("error: file not found: \(file)")
            exit(1)
        }
        testFiles = [file]
    } else {
        // Find all .rok files in tests/ directory
        let testsDir = fm.currentDirectoryPath + "/tests"
        guard fm.fileExists(atPath: testsDir) else {
            print("error: no tests/ directory found")
            exit(1)
        }
        if let items = try? fm.contentsOfDirectory(atPath: testsDir) {
            testFiles = items.filter { $0.hasSuffix(".rok") }
                             .sorted()
                             .map { testsDir + "/" + $0 }
        }
        if testFiles.isEmpty {
            print("No test files found in tests/")
            exit(0)
        }
    }

    var passed = 0
    var failed = 0

    for testFile in testFiles {
        print("Running \(testFile)...")

        guard let source = try? String(contentsOfFile: testFile, encoding: .utf8) else {
            print("  error: could not read \(testFile)")
            failed += 1
            continue
        }

        let diagnostics = DiagnosticEngine()
        let lexer = Lexer(source: source, fileName: testFile, diagnostics: diagnostics)
        let tokens = lexer.tokenize()
        let parser = Parser(tokens: tokens, diagnostics: diagnostics)
        let ast = parser.parse()
        let checker = TypeChecker(ast: ast, diagnostics: diagnostics)
        let typeResult = checker.check()

        if diagnostics.hasErrors {
            diagnostics.dump()
            failed += 1
            continue
        }

        let lowering = MIRLowering(typeCheckResult: typeResult)
        let mir = lowering.lower()
        let optimizer = MIROptimizer()
        let optimized = optimizer.optimize(mir)
        let codeGen = CodeGen()
        let module = codeGen.generate(optimized)
        let vm = VM(module: module, config: RuntimeConfig())

        do {
            try vm.run()
            passed += 1
        } catch {
            let st = vm.captureStackTrace(error: error as! VMError)
            print(st)
            failed += 1
        }
    }

    print("\n\(testFiles.count) test file(s): \(passed) passed, \(failed) failed")
    if failed > 0 { exit(1) }
}

// MARK: - Build Native

func buildNativeCommand(file: String, dumpLLVM: Bool) {
    guard FileManager.default.fileExists(atPath: file) else {
        print("error: file not found: \(file)")
        exit(1)
    }

    guard let source = try? String(contentsOfFile: file, encoding: .utf8) else {
        print("error: could not read file: \(file)")
        exit(1)
    }

    let outputPath: String
    if file.hasSuffix(".rok") {
        outputPath = String(file.dropLast(4))
    } else {
        outputPath = file + ".native"
    }

    // Find Runtime/ directory relative to the executable or working directory
    let runtimeDir = findRuntimeDir()

    do {
        let result = try LLVMCodeGen.compileToNative(
            source: source,
            fileName: file,
            outputPath: outputPath,
            runtimeDir: runtimeDir,
            emitLLVM: false
        )
        print("\(file) \u{2192} \(result)")
        if dumpLLVM {
            if let llSource = try? String(contentsOfFile: outputPath + ".ll", encoding: .utf8) {
                print("\n--- LLVM IR ---")
                print(llSource)
                print("--- End LLVM IR ---")
            }
        }
        print("OK")
    } catch {
        print("error: \(error)")
        exit(1)
    }
}

func emitLLVMCommand(file: String) {
    guard FileManager.default.fileExists(atPath: file) else {
        print("error: file not found: \(file)")
        exit(1)
    }

    guard let source = try? String(contentsOfFile: file, encoding: .utf8) else {
        print("error: could not read file: \(file)")
        exit(1)
    }

    let diagnostics = DiagnosticEngine()
    let lexer = Lexer(source: source, fileName: file, diagnostics: diagnostics)
    let tokens = lexer.tokenize()
    let parser = Parser(tokens: tokens, diagnostics: diagnostics)
    let ast = parser.parse()
    let checker = TypeChecker(ast: ast, diagnostics: diagnostics)
    let typeResult = checker.check()

    if diagnostics.hasErrors {
        diagnostics.dump()
        print("\n\(diagnostics.errorCount) error(s)")
        exit(1)
    }

    let lowering = MIRLowering(typeCheckResult: typeResult)
    let unoptimized = lowering.lower()
    let optimizer = MIROptimizer()
    let optimized = optimizer.optimize(unoptimized)

    let codeGen = LLVMCodeGen()
    let llvmIR = codeGen.emit(module: optimized)
    print(llvmIR)
}

func runNativeCommand(file: String) {
    guard FileManager.default.fileExists(atPath: file) else {
        print("error: file not found: \(file)")
        exit(1)
    }

    guard let source = try? String(contentsOfFile: file, encoding: .utf8) else {
        print("error: could not read file: \(file)")
        exit(1)
    }

    let outputPath = NSTemporaryDirectory() + "rockit_native_\(ProcessInfo.processInfo.processIdentifier)"
    let runtimeDir = findRuntimeDir()

    do {
        let binary = try LLVMCodeGen.compileToNative(
            source: source,
            fileName: file,
            outputPath: outputPath,
            runtimeDir: runtimeDir,
            emitLLVM: false
        )

        // Execute the native binary
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = Array(CommandLine.arguments.dropFirst(3))  // Forward remaining args
        try process.run()
        process.waitUntilExit()

        // Clean up
        try? FileManager.default.removeItem(atPath: binary)
        try? FileManager.default.removeItem(atPath: binary + ".ll")

        exit(process.terminationStatus)
    } catch {
        print("error: \(error)")
        exit(1)
    }
}

/// Find the Runtime/ directory containing C runtime source files.
func findRuntimeDir() -> String {
    let fm = FileManager.default

    // Try relative to current working directory
    let cwd = fm.currentDirectoryPath
    let cwdRuntime = cwd + "/Runtime"
    if fm.fileExists(atPath: cwdRuntime + "/rockit_runtime.c") {
        return cwdRuntime
    }

    // Try relative to the executable
    let execPath = CommandLine.arguments[0]
    let execDir = (execPath as NSString).deletingLastPathComponent
    let execRuntime = execDir + "/../Runtime"
    if fm.fileExists(atPath: execRuntime + "/rockit_runtime.c") {
        return execRuntime
    }

    // Try the project source tree (common during development)
    let devRuntime = execDir + "/../../Runtime"
    if fm.fileExists(atPath: devRuntime + "/rockit_runtime.c") {
        return devRuntime
    }

    // Fallback: assume cwd
    return cwdRuntime
}

// MARK: - Main

let args = CommandLine.arguments

guard args.count >= 2 else {
    printUsage()
    exit(0)
}

switch args[1] {
case "lex":
    guard args.count >= 3 else {
        print("error: lex requires a file argument")
        exit(1)
    }
    let dumpTokens = args.contains("--dump-tokens")
    lex(file: args[2], dumpTokens: dumpTokens)

case "parse":
    guard args.count >= 3 else {
        print("error: parse requires a file argument")
        exit(1)
    }
    let dumpAST = args.contains("--dump-ast")
    parseCommand(file: args[2], dumpAST: dumpAST)

case "check":
    guard args.count >= 3 else {
        print("error: check requires a file argument")
        exit(1)
    }
    let dumpTypes = args.contains("--dump-types")
    checkCommand(file: args[2], dumpTypes: dumpTypes)

case "lower":
    guard args.count >= 3 else {
        print("error: lower requires a file argument")
        exit(1)
    }
    let dumpMIR = args.contains("--dump-mir")
    let dumpUnopt = args.contains("--dump-mir-unoptimized")
    lowerCommand(file: args[2], dumpMIR: dumpMIR, dumpUnoptimized: dumpUnopt)

case "build":
    guard args.count >= 3 else {
        print("error: build requires a file argument")
        exit(1)
    }
    let dumpBytecode = args.contains("--dump-bytecode")
    buildCommand(file: args[2], dumpBytecode: dumpBytecode)

case "build-native":
    guard args.count >= 3 else {
        print("error: build-native requires a file argument")
        exit(1)
    }
    let dumpLLVM = args.contains("--dump-llvm")
    buildNativeCommand(file: args[2], dumpLLVM: dumpLLVM)

case "emit-llvm":
    guard args.count >= 3 else {
        print("error: emit-llvm requires a file argument")
        exit(1)
    }
    emitLLVMCommand(file: args[2])

case "run-native":
    guard args.count >= 3 else {
        print("error: run-native requires a file argument")
        exit(1)
    }
    runNativeCommand(file: args[2])

case "run":
    guard args.count >= 3 else {
        print("error: run requires a file argument")
        exit(1)
    }
    let trace = args.contains("--trace")
    let gcStats = args.contains("--gc-stats")
    runCommand(file: args[2], trace: trace, gcStats: gcStats)

case "launch", "repl":
    replCommand()

case "init":
    let name = args.count >= 3 ? args[2] : "myproject"
    initCommand(name: name)

case "test":
    let file = args.count >= 3 ? args[2] : nil
    testCommand(file: file)

case "version":
    print("rockit \(version)")

case "--help", "-h":
    printUsage()

default:
    // Assume it's a file path
    if args[1].hasSuffix(".rok") {
        lex(file: args[1], dumpTokens: true)
    } else {
        print("error: unknown command '\(args[1])'")
        printUsage()
        exit(1)
    }
}
