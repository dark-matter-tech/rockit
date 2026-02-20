// RenameProvider.swift
// RockitLSP — Rockit Language Server Protocol
// Copyright © 2026 Dark Matter Tech. All rights reserved.

import RockitKit

/// Handles textDocument/rename and textDocument/prepareRename
public final class RenameProvider {

    /// Validate that the symbol at position is renameable and return its range
    public static func prepareRename(
        at position: LSPPosition,
        uri: String,
        analysisResult: AnalysisResult
    ) -> LSPRange? {
        let sourcePos = lspPositionToSourceLocation(position, uri: uri)
        guard let nodeCtx = ASTNavigator.findNode(in: analysisResult.ast, at: sourcePos) else {
            return nil
        }

        switch nodeCtx.kind {
        case .expression(let expr):
            switch expr {
            case .identifier(_, let span):
                return sourceSpanToLSPRange(span)
            case .memberAccess(_, let member, let span):
                return LSPRange(
                    start: LSPPosition(line: span.end.line - 1, character: span.end.column - member.count),
                    end: LSPPosition(line: span.end.line - 1, character: span.end.column)
                )
            default:
                return nil
            }
        case .declaration:
            return sourceSpanToLSPRange(declarationSpan(nodeCtx.kind.asDeclaration!))
        case .parameter(let p):
            return sourceSpanToLSPRange(p.span)
        case .statement:
            return nil
        }
    }

    /// Perform the rename: find all references and build a WorkspaceEdit
    public static func rename(
        at position: LSPPosition,
        uri: String,
        newName: String,
        analysisResult: AnalysisResult
    ) -> LSPWorkspaceEdit? {
        let locations = ReferencesProvider.references(
            at: position,
            uri: uri,
            analysisResult: analysisResult,
            includeDeclaration: true
        )

        if locations.isEmpty { return nil }

        var changes: [String: [LSPTextEdit]] = [:]
        for loc in locations {
            let edit = LSPTextEdit(range: loc.range, newText: newName)
            changes[loc.uri, default: []].append(edit)
        }

        return LSPWorkspaceEdit(changes: changes)
    }
}

// Helper extension on NodeAtPosition.Kind
extension NodeAtPosition.Kind {
    var asDeclaration: RDeclaration? {
        if case .declaration(let d) = self { return d }
        return nil
    }
}
