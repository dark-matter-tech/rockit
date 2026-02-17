// AnalysisEngine.swift
// RockitLSP — Rockit Language Server Protocol
// Copyright © 2026 Dark Matter Tech. All rights reserved.

import Foundation
import RockitKit

/// Result of analyzing a document
public struct AnalysisResult {
    public let tokens: [Token]
    public let ast: SourceFile
    public let typeCheckResult: TypeCheckResult
    public let diagnostics: [Diagnostic]
}

/// Drives the compiler pipeline for LSP analysis
public final class AnalysisEngine {
    private let documentManager: DocumentManager

    public init(documentManager: DocumentManager) {
        self.documentManager = documentManager
    }

    /// Run the full compiler frontend on a document and cache results.
    /// Returns nil if the document is not open.
    public func analyze(uri: String) -> AnalysisResult? {
        guard let text = documentManager.getText(uri) else { return nil }
        let path = uriToPath(uri)

        let diagnosticEngine = DiagnosticEngine()

        // Phase 1: Lex
        let lexer = Lexer(source: text, fileName: path, diagnostics: diagnosticEngine)
        let tokens = lexer.tokenize()

        // Phase 2: Parse
        let parser = Parser(tokens: tokens, diagnostics: diagnosticEngine)
        let ast = parser.parse()

        // Phase 3: Type check (skip import resolution for single-file mode)
        let checker = TypeChecker(ast: ast, diagnostics: diagnosticEngine)
        let typeResult = checker.check()

        let result = AnalysisResult(
            tokens: tokens,
            ast: ast,
            typeCheckResult: typeResult,
            diagnostics: diagnosticEngine.diagnostics
        )

        // Cache for subsequent queries (hover, completion, etc.)
        documentManager.setCachedAnalysis(
            uri: uri,
            tokens: tokens,
            ast: ast,
            result: typeResult,
            diagnostics: diagnosticEngine.diagnostics
        )

        return result
    }

    /// Get cached analysis or re-analyze
    public func getOrAnalyze(uri: String) -> AnalysisResult? {
        if let doc = documentManager.get(uri),
           let tokens = doc.tokens,
           let ast = doc.ast,
           let result = doc.typeCheckResult {
            return AnalysisResult(
                tokens: tokens,
                ast: ast,
                typeCheckResult: result,
                diagnostics: doc.cachedDiagnostics
            )
        }
        return analyze(uri: uri)
    }
}
