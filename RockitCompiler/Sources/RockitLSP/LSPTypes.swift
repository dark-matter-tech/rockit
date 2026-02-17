// LSPTypes.swift
// RockitLSP — Rockit Language Server Protocol
// Copyright © 2026 Dark Matter Tech. All rights reserved.

import Foundation
import RockitKit

// MARK: - LSP Position / Range / Location

/// 0-indexed line and character (UTF-16 code units per LSP spec)
public struct LSPPosition {
    public let line: Int
    public let character: Int

    func toJSON() -> [String: Any] {
        return ["line": line, "character": character]
    }

    init(line: Int, character: Int) {
        self.line = line
        self.character = character
    }

    init?(json: [String: Any]) {
        guard let line = json["line"] as? Int,
              let character = json["character"] as? Int else { return nil }
        self.line = line
        self.character = character
    }
}

/// A range in a document
public struct LSPRange {
    public let start: LSPPosition
    public let end: LSPPosition

    func toJSON() -> [String: Any] {
        return ["start": start.toJSON(), "end": end.toJSON()]
    }

    init(start: LSPPosition, end: LSPPosition) {
        self.start = start
        self.end = end
    }

    init?(json: [String: Any]) {
        guard let startJSON = json["start"] as? [String: Any],
              let endJSON = json["end"] as? [String: Any],
              let start = LSPPosition(json: startJSON),
              let end = LSPPosition(json: endJSON) else { return nil }
        self.start = start
        self.end = end
    }
}

/// A location in a document (URI + range)
public struct LSPLocation {
    public let uri: String
    public let range: LSPRange

    func toJSON() -> [String: Any] {
        return ["uri": uri, "range": range.toJSON()]
    }
}

// MARK: - LSP Diagnostic

public struct LSPDiagnostic {
    public let range: LSPRange
    public let severity: Int  // 1=Error, 2=Warning, 3=Information, 4=Hint
    public let message: String
    public let source: String

    func toJSON() -> [String: Any] {
        return [
            "range": range.toJSON(),
            "severity": severity,
            "message": message,
            "source": source
        ]
    }
}

// MARK: - LSP Completion

public struct LSPCompletionItem {
    public let label: String
    public let kind: Int
    public let detail: String?
    public let insertText: String?

    func toJSON() -> [String: Any] {
        var json: [String: Any] = [
            "label": label,
            "kind": kind
        ]
        if let detail = detail { json["detail"] = detail }
        if let insertText = insertText { json["insertText"] = insertText }
        return json
    }
}

// MARK: - LSP Hover

public struct LSPMarkupContent {
    public let kind: String  // "markdown" or "plaintext"
    public let value: String

    func toJSON() -> [String: Any] {
        return ["kind": kind, "value": value]
    }
}

public struct LSPHover {
    public let contents: LSPMarkupContent
    public let range: LSPRange?

    func toJSON() -> [String: Any] {
        var json: [String: Any] = ["contents": contents.toJSON()]
        if let range = range { json["range"] = range.toJSON() }
        return json
    }
}

// MARK: - LSP Document Symbol

public struct LSPDocumentSymbol {
    public let name: String
    public let detail: String?
    public let kind: Int
    public let range: LSPRange
    public let selectionRange: LSPRange
    public let children: [LSPDocumentSymbol]?

    func toJSON() -> [String: Any] {
        var json: [String: Any] = [
            "name": name,
            "kind": kind,
            "range": range.toJSON(),
            "selectionRange": selectionRange.toJSON()
        ]
        if let detail = detail { json["detail"] = detail }
        if let children = children {
            json["children"] = children.map { $0.toJSON() }
        }
        return json
    }
}

// MARK: - LSP Signature Help

public struct LSPParameterInformation {
    public let label: String

    func toJSON() -> [String: Any] {
        return ["label": label]
    }
}

public struct LSPSignatureInformation {
    public let label: String
    public let parameters: [LSPParameterInformation]

    func toJSON() -> [String: Any] {
        return [
            "label": label,
            "parameters": parameters.map { $0.toJSON() }
        ]
    }
}

public struct LSPSignatureHelp {
    public let signatures: [LSPSignatureInformation]
    public let activeSignature: Int
    public let activeParameter: Int

    func toJSON() -> [String: Any] {
        return [
            "signatures": signatures.map { $0.toJSON() },
            "activeSignature": activeSignature,
            "activeParameter": activeParameter
        ]
    }
}

// MARK: - LSP Constants

public enum LSPSymbolKind {
    public static let file = 1
    public static let module_ = 2
    public static let namespace = 3
    public static let class_ = 5
    public static let method = 6
    public static let property = 7
    public static let field = 8
    public static let constructor = 9
    public static let enum_ = 10
    public static let interface_ = 11
    public static let function_ = 12
    public static let variable = 13
    public static let constant = 14
    public static let object_ = 19
    public static let enumMember = 22
    public static let typeParameter = 26
}

public enum LSPCompletionItemKind {
    public static let text = 1
    public static let method = 2
    public static let function_ = 3
    public static let constructor = 4
    public static let field = 5
    public static let variable = 6
    public static let class_ = 7
    public static let interface_ = 8
    public static let module_ = 9
    public static let property = 10
    public static let keyword = 14
    public static let snippet = 15
    public static let enumMember = 20
    public static let constant = 21
    public static let struct_ = 22
    public static let event = 23
    public static let typeParameter = 25
}

// MARK: - Position Conversion

/// Convert LSP position (0-indexed line, 0-indexed character) to Rockit SourceLocation (1-indexed line, 0-indexed column)
public func lspPositionToSourceLocation(_ pos: LSPPosition, uri: String) -> SourceLocation {
    return SourceLocation(file: uriToPath(uri), line: pos.line + 1, column: pos.character)
}

/// Convert Rockit SourceLocation to LSP position
public func sourceLocationToLSPPosition(_ loc: SourceLocation) -> LSPPosition {
    return LSPPosition(line: loc.line - 1, character: loc.column)
}

/// Convert Rockit SourceSpan to LSP range
public func sourceSpanToLSPRange(_ span: SourceSpan) -> LSPRange {
    return LSPRange(
        start: sourceLocationToLSPPosition(span.start),
        end: sourceLocationToLSPPosition(span.end)
    )
}

// MARK: - URI Helpers

/// Convert file:// URI to filesystem path
public func uriToPath(_ uri: String) -> String {
    if uri.hasPrefix("file://") {
        let path = String(uri.dropFirst(7))
        // Handle percent-encoded characters
        return path.removingPercentEncoding ?? path
    }
    return uri
}

/// Convert filesystem path to file:// URI
public func pathToURI(_ path: String) -> String {
    return "file://\(path)"
}

// MARK: - Expression Span Helper

/// Extract the SourceSpan from any Expression case
public func expressionSpan(_ expr: RockitKit.Expression) -> SourceSpan {
    switch expr {
    case .intLiteral(_, let span),
         .floatLiteral(_, let span),
         .stringLiteral(_, let span),
         .interpolatedString(_, let span),
         .boolLiteral(_, let span),
         .nullLiteral(let span),
         .identifier(_, let span),
         .this(let span),
         .super(let span),
         .binary(_, _, _, let span),
         .unaryPrefix(_, _, let span),
         .unaryPostfix(_, _, let span),
         .memberAccess(_, _, let span),
         .nullSafeMemberAccess(_, _, let span),
         .subscriptAccess(_, _, let span),
         .call(_, _, _, let span),
         .typeCheck(_, _, let span),
         .typeCast(_, _, let span),
         .safeCast(_, _, let span),
         .nonNullAssert(_, let span),
         .awaitExpr(_, let span),
         .concurrentBlock(_, let span),
         .elvis(_, _, let span),
         .range(_, _, _, let span),
         .parenthesized(_, let span),
         .error(let span):
        return span
    case .ifExpr(let ie):
        return ie.span
    case .whenExpr(let we):
        return we.span
    case .lambda(let le):
        return le.span
    }
}

/// Extract the SourceSpan from any Statement case
public func statementSpan(_ stmt: RockitKit.Statement) -> SourceSpan? {
    switch stmt {
    case .propertyDecl(let p): return p.span
    case .expression(let e): return expressionSpan(e)
    case .returnStmt(_, let span): return span
    case .breakStmt(let span): return span
    case .continueStmt(let span): return span
    case .throwStmt(_, let span): return span
    case .tryCatch(let tc): return tc.span
    case .assignment(let a): return a.span
    case .forLoop(let f): return f.span
    case .whileLoop(let w): return w.span
    case .doWhileLoop(let d): return d.span
    case .declaration(let d): return declarationSpan(d)
    case .destructuringDecl(let d): return d.span
    }
}

/// Extract the SourceSpan from any Declaration case
public func declarationSpan(_ decl: RockitKit.Declaration) -> SourceSpan {
    switch decl {
    case .function(let f): return f.span
    case .property(let p): return p.span
    case .classDecl(let c): return c.span
    case .interfaceDecl(let i): return i.span
    case .enumDecl(let e): return e.span
    case .objectDecl(let o): return o.span
    case .actorDecl(let a): return a.span
    case .viewDecl(let v): return v.span
    case .navigationDecl(let n): return n.span
    case .themeDecl(let t): return t.span
    case .typeAlias(let ta): return ta.span
    }
}
