// DocumentManager.swift
// RockitLSP — Rockit Language Server Protocol
// Copyright © 2026 Dark Matter Tech. All rights reserved.

import Foundation
import RockitKit

/// Tracks the state of all open documents
public final class DocumentManager {

    /// State for a single open document
    public struct DocumentState {
        public let uri: String
        public var version: Int
        public var text: String
        public var lines: [Substring]
        public var tokens: [Token]?
        public var ast: SourceFile?
        public var typeCheckResult: TypeCheckResult?
        public var cachedDiagnostics: [Diagnostic]
    }

    private var documents: [String: DocumentState] = [:]

    public init() {}

    /// Register a newly opened document
    public func open(uri: String, text: String, version: Int) {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        documents[uri] = DocumentState(
            uri: uri,
            version: version,
            text: text,
            lines: lines,
            tokens: nil,
            ast: nil,
            typeCheckResult: nil,
            cachedDiagnostics: []
        )
    }

    /// Update document content (full sync)
    public func update(uri: String, text: String, version: Int) {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        documents[uri] = DocumentState(
            uri: uri,
            version: version,
            text: text,
            lines: lines,
            tokens: nil,
            ast: nil,
            typeCheckResult: nil,
            cachedDiagnostics: []
        )
    }

    /// Remove a closed document
    public func close(uri: String) {
        documents.removeValue(forKey: uri)
    }

    /// Get the document state
    public func get(_ uri: String) -> DocumentState? {
        return documents[uri]
    }

    /// Get the raw text for a document
    public func getText(_ uri: String) -> String? {
        return documents[uri]?.text
    }

    /// Get the split lines for a document
    public func getLines(_ uri: String) -> [Substring]? {
        return documents[uri]?.lines
    }

    /// Store cached analysis results
    public func setCachedAnalysis(uri: String, tokens: [Token], ast: SourceFile,
                                   result: TypeCheckResult, diagnostics: [Diagnostic]) {
        documents[uri]?.tokens = tokens
        documents[uri]?.ast = ast
        documents[uri]?.typeCheckResult = result
        documents[uri]?.cachedDiagnostics = diagnostics
    }
}
