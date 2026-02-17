// HoverProvider.swift
// RockitLSP — Rockit Language Server Protocol
// Copyright © 2026 Dark Matter Tech. All rights reserved.

import RockitKit

/// Implements textDocument/hover
public final class HoverProvider {

    /// Compute hover information at the given position
    public static func hover(
        at position: LSPPosition,
        uri: String,
        analysisResult: AnalysisResult
    ) -> LSPHover? {
        let sourcePos = lspPositionToSourceLocation(position, uri: uri)

        guard let nodeCtx = ASTNavigator.findNode(in: analysisResult.ast, at: sourcePos) else {
            return nil
        }

        switch nodeCtx.kind {
        case .expression(let expr):
            return hoverForExpression(expr, analysisResult: analysisResult)

        case .declaration(let decl):
            return hoverForDeclaration(decl)

        case .parameter(let param):
            let typeStr = param.type?.summary ?? "Unknown"
            let text = "```rockit\n\(param.name): \(typeStr)\n```"
            return LSPHover(
                contents: LSPMarkupContent(kind: "markdown", value: text),
                range: sourceSpanToLSPRange(param.span)
            )

        case .statement:
            return nil
        }
    }

    // MARK: - Private

    private static func hoverForExpression(_ expr: RockitKit.Expression, analysisResult: AnalysisResult) -> LSPHover? {
        let span = expressionSpan(expr)
        let exprId = ExpressionID(span)
        let type = analysisResult.typeCheckResult.typeMap[exprId]

        switch expr {
        case .identifier(let name, _):
            if let sym = analysisResult.typeCheckResult.symbolTable.lookup(name) {
                let text = formatSymbolHover(sym)
                return LSPHover(
                    contents: LSPMarkupContent(kind: "markdown", value: text),
                    range: sourceSpanToLSPRange(span)
                )
            }
            if let type = type {
                return LSPHover(
                    contents: LSPMarkupContent(kind: "markdown", value: "`\(type)`"),
                    range: sourceSpanToLSPRange(span)
                )
            }

        case .memberAccess(_, let member, _):
            if let type = type {
                let text = "```rockit\n\(member): \(type)\n```"
                return LSPHover(
                    contents: LSPMarkupContent(kind: "markdown", value: text),
                    range: sourceSpanToLSPRange(span)
                )
            }

        case .call(let callee, _, _, _):
            if case .identifier(let name, _) = callee {
                if let sym = analysisResult.typeCheckResult.symbolTable.lookup(name) {
                    let text = formatSymbolHover(sym)
                    return LSPHover(
                        contents: LSPMarkupContent(kind: "markdown", value: text),
                        range: sourceSpanToLSPRange(span)
                    )
                }
            }
            if let type = type {
                return LSPHover(
                    contents: LSPMarkupContent(kind: "markdown", value: "`\(type)`"),
                    range: sourceSpanToLSPRange(span)
                )
            }

        default:
            if let type = type {
                return LSPHover(
                    contents: LSPMarkupContent(kind: "markdown", value: "`\(type)`"),
                    range: sourceSpanToLSPRange(span)
                )
            }
        }

        return nil
    }

    private static func hoverForDeclaration(_ decl: Declaration) -> LSPHover? {
        let span = declarationSpan(decl)
        let text: String

        switch decl {
        case .function(let f):
            let params = f.parameters.map { p -> String in
                var s = p.name
                if let t = p.type { s += ": \(t.summary)" }
                return s
            }
            let retStr = f.returnType.map { ": \($0.summary)" } ?? ""
            let mods = f.modifiers.isEmpty ? "" : f.modifiers.map { "\($0)" }.joined(separator: " ") + " "
            text = "```rockit\n\(mods)fun \(f.name)(\(params.joined(separator: ", ")))\(retStr)\n```"

        case .property(let p):
            let keyword = p.isVal ? "val" : "var"
            let typeStr = p.type.map { ": \($0.summary)" } ?? ""
            text = "```rockit\n\(keyword) \(p.name)\(typeStr)\n```"

        case .classDecl(let c):
            let prefix = c.modifiers.contains(.data) ? "data " :
                         c.modifiers.contains(.sealed) ? "sealed " :
                         c.modifiers.contains(.abstract) ? "abstract " : ""
            text = "```rockit\n\(prefix)class \(c.name)\n```"

        case .interfaceDecl(let i):
            text = "```rockit\ninterface \(i.name)\n```"

        case .enumDecl(let e):
            text = "```rockit\nenum class \(e.name)\n```"

        case .actorDecl(let a):
            text = "```rockit\nactor \(a.name)\n```"

        case .viewDecl(let v):
            let params = v.parameters.map { p -> String in
                var s = p.name
                if let t = p.type { s += ": \(t.summary)" }
                return s
            }
            text = "```rockit\nview \(v.name)(\(params.joined(separator: ", ")))\n```"

        case .objectDecl(let o):
            let prefix = o.isCompanion ? "companion " : ""
            text = "```rockit\n\(prefix)object \(o.name)\n```"

        default:
            return nil
        }

        return LSPHover(
            contents: LSPMarkupContent(kind: "markdown", value: text),
            range: sourceSpanToLSPRange(span)
        )
    }

    private static func formatSymbolHover(_ sym: Symbol) -> String {
        switch sym.kind {
        case .function:
            if case .function(let params, let ret) = sym.type {
                let paramStr = params.map { "\($0)" }.joined(separator: ", ")
                return "```rockit\nfun \(sym.name)(\(paramStr)): \(ret)\n```"
            }
            return "```rockit\nfun \(sym.name)\n```"

        case .variable(let isMutable):
            let keyword = isMutable ? "var" : "val"
            return "```rockit\n\(keyword) \(sym.name): \(sym.type)\n```"

        case .parameter:
            return "```rockit\n\(sym.name): \(sym.type)\n```"

        case .typeDeclaration:
            return "```rockit\nclass \(sym.name)\n```"

        case .enumEntry:
            return "```rockit\n\(sym.name)\n```"

        case .typeAlias:
            return "```rockit\ntypealias \(sym.name) = \(sym.type)\n```"

        case .typeParameter:
            return "```rockit\n\(sym.name)\n```"
        }
    }
}
