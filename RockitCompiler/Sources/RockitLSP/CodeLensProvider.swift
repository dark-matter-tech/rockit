// CodeLensProvider.swift
// RockitLSP — Rockit Language Server Protocol
// Copyright © 2026 Dark Matter Tech. All rights reserved.

import Foundation
import RockitKit

/// Provides CodeLens items for @Test functions, showing inline pass/fail indicators
public final class CodeLensProvider {

    /// Result of running a single test function
    enum TestResult {
        case pass
        case fail(String)
        case compileError(String)
    }

    /// Cache: uri -> [testFunctionName: TestResult]
    private static var testResultsCache: [String: [String: TestResult]] = [:]

    // MARK: - Public API

    /// Return CodeLens items for all @Test functions in the document.
    /// Uses cached test results if available, otherwise shows "Run Test".
    public static func codeLenses(
        for result: AnalysisResult,
        uri: String
    ) -> [LSPCodeLens] {
        var lenses: [LSPCodeLens] = []
        let cached = testResultsCache[uri] ?? [:]

        for decl in result.ast.declarations {
            guard case .function(let fn) = decl else { continue }
            let hasTestAnnotation = fn.annotations.contains { $0.name == "Test" }
            guard hasTestAnnotation else { continue }

            let line = fn.span.start.line - 1  // Convert to 0-indexed
            let range = LSPRange(
                start: LSPPosition(line: line, character: 0),
                end: LSPPosition(line: line, character: 0)
            )

            let command: LSPCommand
            if let testResult = cached[fn.name] {
                switch testResult {
                case .pass:
                    command = LSPCommand(
                        title: "$(pass) \(fn.name)",
                        command: "rockit.runTest",
                        arguments: [fn.name]
                    )
                case .fail(let message):
                    command = LSPCommand(
                        title: "$(error) \(fn.name) — \(message)",
                        command: "rockit.runTest",
                        arguments: [fn.name]
                    )
                case .compileError(let message):
                    command = LSPCommand(
                        title: "$(warning) \(fn.name) — \(message)",
                        command: "rockit.runTest",
                        arguments: [fn.name]
                    )
                }
            } else {
                command = LSPCommand(
                    title: "$(testing) Run Test",
                    command: "rockit.runTest",
                    arguments: [fn.name]
                )
            }

            lenses.append(LSPCodeLens(range: range, command: command))
        }

        return lenses
    }

    /// Run all @Test functions in a file and cache results.
    /// Called from the didSave handler.
    public static func runTests(
        source: String,
        filePath: String,
        uri: String,
        workspaceRoot: String?
    ) {
        let diagnostics = DiagnosticEngine()
        let lexer = Lexer(source: source, fileName: filePath, diagnostics: diagnostics)
        let tokens = lexer.tokenize()
        let parser = Parser(tokens: tokens, diagnostics: diagnostics)
        let parsedAST = parser.parse()

        let sourceDir = (filePath as NSString).deletingLastPathComponent
        let stdlibPaths: [String] = findStdlibDir(workspaceRoot: workspaceRoot).map { [$0] } ?? []
        let importResolver = ImportResolver(sourceDir: sourceDir, libPaths: stdlibPaths, diagnostics: diagnostics)
        let ast = importResolver.resolve(parsedAST)

        let checker = TypeChecker(ast: ast, diagnostics: diagnostics)
        _ = checker.check()

        // Discover @Test functions
        let testFunctions = discoverTestFunctions(ast: ast)
        guard !testFunctions.isEmpty else { return }

        if diagnostics.hasErrors {
            // All tests get compile error
            var results: [String: TestResult] = [:]
            for testFn in testFunctions {
                results[testFn] = .compileError("compile error")
            }
            testResultsCache[uri] = results
            return
        }

        // Strip main() and run each test individually
        let sourceWithoutMain = stripMainFunction(source)
        var results: [String: TestResult] = [:]

        for testFn in testFunctions {
            let wrapperSource = sourceWithoutMain + "\nfun main() { \(testFn)() }\n"

            let wDiag = DiagnosticEngine()
            let wLexer = Lexer(source: wrapperSource, fileName: filePath, diagnostics: wDiag)
            let wTokens = wLexer.tokenize()
            let wParser = Parser(tokens: wTokens, diagnostics: wDiag)
            let wParsedAst = wParser.parse()
            let wImportResolver = ImportResolver(sourceDir: sourceDir, libPaths: stdlibPaths, diagnostics: wDiag)
            let wAst = wImportResolver.resolve(wParsedAst)
            let wChecker = TypeChecker(ast: wAst, diagnostics: wDiag)
            let wResult = wChecker.check()

            if wDiag.hasErrors {
                results[testFn] = .compileError("compile error")
                continue
            }

            let lowering = MIRLowering(typeCheckResult: wResult)
            let mir = lowering.lower()
            let optimizer = MIROptimizer()
            let optimized = optimizer.optimize(mir)
            let codeGen = CodeGen()
            let module = codeGen.generate(optimized)
            let vm = VM(module: module, config: RuntimeConfig())

            do {
                try vm.run()
                results[testFn] = .pass
            } catch {
                if let vmErr = error as? VMError {
                    results[testFn] = .fail("\(vmErr)")
                } else {
                    results[testFn] = .fail("\(error)")
                }
            }
        }

        testResultsCache[uri] = results
    }

    /// Clear cached test results for a URI (called on didChange)
    public static func invalidateCache(uri: String) {
        testResultsCache.removeValue(forKey: uri)
    }

    // MARK: - Private Helpers

    /// Discover functions with @Test annotation in the AST
    private static func discoverTestFunctions(ast: SourceFile) -> [String] {
        var testFunctions: [String] = []
        for decl in ast.declarations {
            if case .function(let fn) = decl {
                if fn.annotations.contains(where: { $0.name == "Test" }) {
                    testFunctions.append(fn.name)
                }
            }
        }
        return testFunctions
    }

    /// Strip the main() function from source code for test wrapper injection
    private static func stripMainFunction(_ source: String) -> String {
        guard let range = source.range(of: "fun main(") else { return source }
        let before = source[source.startIndex..<range.lowerBound]

        let afterStart = range.lowerBound
        var depth = 0
        var foundOpenBrace = false
        var endIdx = source.endIndex
        var idx = source.index(after: afterStart)
        while idx < source.endIndex {
            let ch = source[idx]
            if ch == "{" {
                depth += 1
                foundOpenBrace = true
            } else if ch == "}" {
                depth -= 1
                if foundOpenBrace && depth == 0 {
                    endIdx = source.index(after: idx)
                    break
                }
            }
            idx = source.index(after: idx)
        }

        let after = source[endIdx..<source.endIndex]
        return String(before) + String(after)
    }

    /// Find the stdlib directory for import resolution
    private static func findStdlibDir(workspaceRoot: String?) -> String? {
        let fm = FileManager.default

        // 1. Check ROCKIT_STDLIB_DIR environment variable
        if let envDir = ProcessInfo.processInfo.environment["ROCKIT_STDLIB_DIR"],
           fm.fileExists(atPath: envDir) {
            return envDir
        }

        // 2. Try Stage1/stdlib relative to workspace root (development)
        if let root = workspaceRoot {
            let devStdlib = (root as NSString).appendingPathComponent("Stage1/stdlib")
            if fm.fileExists(atPath: (devStdlib as NSString).appendingPathComponent("rockit")) {
                return devStdlib
            }
        }

        // 3. Try Stage1/stdlib relative to CWD (development)
        let cwd = fm.currentDirectoryPath
        let cwdStdlib = (cwd as NSString).appendingPathComponent("Stage1/stdlib")
        if fm.fileExists(atPath: (cwdStdlib as NSString).appendingPathComponent("rockit")) {
            return cwdStdlib
        }

        // 4. Try relative to the executable (installed: share/rockit/stdlib)
        let execPath = CommandLine.arguments[0]
        let execDir = (execPath as NSString).deletingLastPathComponent
        let installedStdlib = ((execDir as NSString).appendingPathComponent("..") as NSString)
            .appendingPathComponent("share/rockit/stdlib")
        if fm.fileExists(atPath: (installedStdlib as NSString).appendingPathComponent("rockit")) {
            return installedStdlib
        }

        return nil
    }
}
