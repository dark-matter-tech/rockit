// main.swift
// MoonCLI — Moon Language Compiler
// Copyright © 2026 Dark Matter Tech. All rights reserved.

import Foundation
import MoonKit

let version = "0.1.0-alpha"

func printUsage() {
    print("""
    moonc \(version) — Moon Language Compiler
    Dark Matter Tech

    USAGE:
        moonc <command> [options] <file>

    COMMANDS:
        lex <file.moon>       Tokenize and dump tokens
        parse <file.moon>     Parse and dump AST
        check <file.moon>     Type-check and report diagnostics
        lower <file.moon>     Lower to MIR and dump
        build <file.moon>     Compile to bytecode (.moonb)
        run <file>            Execute a .moon or .moonb file
        version               Print version

    OPTIONS:
        --dump-tokens         Show token stream (with lex)
        --dump-ast            Show AST (with parse)
        --dump-types          Show inferred types (with check)
        --dump-mir            Show optimized MIR (with lower)
        --dump-mir-unoptimized Show MIR before optimization
        --dump-bytecode       Show disassembled bytecode (with build)
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

    // Serialize to .moonb
    let outputPath = file.hasSuffix(".moon")
        ? String(file.dropLast(5)) + ".moonb"
        : file + ".moonb"

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
    print("\n\(file) → \(outputPath)")
    print("  \(funcCount) function(s), \(bytecodeSize) bytes bytecode, \(totalSize) bytes total")
    print("OK")
}

func runCommand(file: String, trace: Bool, gcStats: Bool) {
    guard FileManager.default.fileExists(atPath: file) else {
        print("error: file not found: \(file)")
        exit(1)
    }

    let module: BytecodeModule

    if file.hasSuffix(".moonb") {
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

case "run":
    guard args.count >= 3 else {
        print("error: run requires a file argument")
        exit(1)
    }
    let trace = args.contains("--trace")
    let gcStats = args.contains("--gc-stats")
    runCommand(file: args[2], trace: trace, gcStats: gcStats)

case "version":
    print("moonc \(version)")

case "--help", "-h":
    printUsage()

default:
    // Assume it's a file path
    if args[1].hasSuffix(".moon") {
        lex(file: args[1], dumpTokens: true)
    } else {
        print("error: unknown command '\(args[1])'")
        printUsage()
        exit(1)
    }
}
