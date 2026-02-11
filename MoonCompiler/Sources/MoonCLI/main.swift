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
        build <file.moon>     Compile to bytecode (coming soon)
        version               Print version

    OPTIONS:
        --dump-tokens         Show token stream (with lex)
        --dump-ast            Show AST (with parse)
        --dump-types          Show inferred types (with check)
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
