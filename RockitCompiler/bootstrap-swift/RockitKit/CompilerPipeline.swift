// CompilerPipeline.swift
// RockitKit — Rockit Language Compiler
// Copyright © 2026 Dark Matter Tech. All rights reserved.
//
// DO-178C / DO-330 Modular Compiler Architecture
//
// This file defines the formal phase protocol, pipeline, and compilation
// context that enable the Rockit compiler to be qualified as a DO-330
// TQL-1 development tool for DAL A software.
//
// Key properties:
//   - Every phase has a typed Input/Output contract
//   - Every phase is independently testable
//   - The pipeline captures intermediate artifacts for audit
//   - Diagnostics are isolated per phase
//   - Source traceability flows through all phases

import Foundation

// MARK: - Compilation Context

/// Configuration and shared state that flows through the compilation pipeline.
/// Immutable after creation — phases read from it but do not modify it.
public struct CompilationContext {
    /// Source file name (for diagnostics and traceability)
    public let fileName: String
    /// Safety level for DO-178C verification (nil = no safety checking)
    public let safetyLevel: SafetyLevel?
    /// Library search paths for import resolution
    public let libPaths: [String]
    /// Runtime directory path
    public let runtimeDir: String
    /// Target output path
    public let outputPath: String
    /// Whether to emit LLVM IR only (no linking)
    public let emitLLVM: Bool
    /// Whether this is a freestanding (no-runtime) build
    public let noRuntime: Bool
    /// Compiler version identifier for audit reports
    public let compilerVersion: String
    /// Build timestamp (ISO 8601)
    public let buildTimestamp: String
    /// Path to write JSON audit report (nil = no audit)
    public let auditOutputPath: String?

    public init(fileName: String, safetyLevel: SafetyLevel? = nil,
                libPaths: [String] = [], runtimeDir: String = "",
                outputPath: String = "", emitLLVM: Bool = false,
                noRuntime: Bool = false, auditOutputPath: String? = nil) {
        self.fileName = fileName
        self.safetyLevel = safetyLevel
        self.libPaths = libPaths
        self.runtimeDir = runtimeDir
        self.outputPath = outputPath
        self.emitLLVM = emitLLVM
        self.noRuntime = noRuntime
        self.compilerVersion = "0.1.0-alpha"
        let formatter = ISO8601DateFormatter()
        self.buildTimestamp = formatter.string(from: Date())
        self.auditOutputPath = auditOutputPath
    }
}

// MARK: - Phase Artifact

/// A captured intermediate result from a compiler phase, for audit and traceability.
public struct PhaseArtifact {
    /// Phase that produced this artifact
    public let phaseName: String
    /// Wall-clock duration of the phase in seconds
    public let duration: TimeInterval
    /// Number of diagnostics (errors + warnings) added by this phase
    public let diagnosticCount: Int
    /// Human-readable summary of the output
    public let summary: String

    public func toJSON() -> [String: Any] {
        return [
            "phase": phaseName,
            "durationSeconds": duration,
            "diagnosticCount": diagnosticCount,
            "summary": summary,
        ]
    }
}

// MARK: - Compiler Phase Protocol

/// Formal contract for a compiler phase.
///
/// DO-330 6.3.1: Each component of the tool shall have a defined interface.
/// Every phase declares its Input and Output types. The pipeline enforces
/// that phase N's Output matches phase N+1's Input.
///
/// Phases must be:
///   - Deterministic: same Input always produces same Output
///   - Side-effect free: only reads Input, only writes Output
///   - Independently testable: can be run with synthetic Input
public protocol CompilerPhase {
    /// The type this phase consumes
    associatedtype Input
    /// The type this phase produces
    associatedtype Output

    /// Human-readable phase name (for logging, audit trail)
    var name: String { get }

    /// Execute the phase.
    ///
    /// - Parameters:
    ///   - input: The typed input from the previous phase
    ///   - context: Compilation configuration (read-only)
    ///   - diagnostics: Diagnostic collector for this phase
    /// - Returns: The typed output for the next phase
    /// - Throws: If the phase encounters a fatal error
    func execute(input: Input, context: CompilationContext,
                 diagnostics: DiagnosticEngine) throws -> Output
}

// MARK: - Concrete Phases

/// Phase 1: Lexer — Source text → Token stream
public struct LexPhase: CompilerPhase {
    public typealias Input = String // source code
    public typealias Output = [Token]

    public let name = "Lexer"

    public init() {}

    public func execute(input: String, context: CompilationContext,
                        diagnostics: DiagnosticEngine) throws -> [Token] {
        let lexer = Lexer(source: input, fileName: context.fileName, diagnostics: diagnostics)
        return lexer.tokenize()
    }
}

/// Phase 2: Parser — Token stream → AST
public struct ParsePhase: CompilerPhase {
    public typealias Input = [Token]
    public typealias Output = SourceFile

    public let name = "Parser"

    public init() {}

    public func execute(input: [Token], context: CompilationContext,
                        diagnostics: DiagnosticEngine) throws -> SourceFile {
        let parser = Parser(tokens: input, diagnostics: diagnostics)
        return parser.parse()
    }
}

/// Phase 3: Import Resolution — AST with imports → Merged AST
public struct ImportPhase: CompilerPhase {
    public typealias Input = SourceFile
    public typealias Output = SourceFile

    public let name = "Import Resolution"

    public init() {}

    public func execute(input: SourceFile, context: CompilationContext,
                        diagnostics: DiagnosticEngine) throws -> SourceFile {
        let sourceDir = (context.fileName as NSString).deletingLastPathComponent
        let resolver = ImportResolver(sourceDir: sourceDir, libPaths: context.libPaths,
                                      diagnostics: diagnostics)
        return resolver.resolve(input)
    }
}

/// Phase 4: Type Checker — Merged AST → Typed AST with symbol table
public struct TypeCheckPhase: CompilerPhase {
    public typealias Input = SourceFile
    public typealias Output = TypeCheckResult

    public let name = "Type Checker"

    public init() {}

    public func execute(input: SourceFile, context: CompilationContext,
                        diagnostics: DiagnosticEngine) throws -> TypeCheckResult {
        let checker = TypeChecker(ast: input, diagnostics: diagnostics)
        let result = checker.check()
        if diagnostics.hasErrors {
            throw CompilerPipelineError.phaseErrors(name, diagnostics.errorCount)
        }
        return result
    }
}

/// Phase 5: Safety Verification — Typed AST → Safety result (pass-through on success)
/// Only runs when safetyLevel is set. Read-only analysis — does not modify AST.
public struct SafetyPhase: CompilerPhase {
    public typealias Input = TypeCheckResult
    public typealias Output = TypeCheckResult // pass-through

    public let name = "Safety Verification"

    public init() {}

    public func execute(input: TypeCheckResult, context: CompilationContext,
                        diagnostics: DiagnosticEngine) throws -> TypeCheckResult {
        guard let level = context.safetyLevel else {
            return input // No safety level → pass-through
        }
        let verifier = SafetyVerifier(level: level, ast: input.ast, diagnostics: diagnostics)
        let result = verifier.verify()
        if !result.passed {
            throw CompilerPipelineError.safetyViolations(level, result.violations)
        }
        return input
    }
}

/// Phase 6: MIR Lowering — Typed AST → MIR
public struct MIRLowerPhase: CompilerPhase {
    public typealias Input = TypeCheckResult
    public typealias Output = MIRModule

    public let name = "MIR Lowering"

    public init() {}

    public func execute(input: TypeCheckResult, context: CompilationContext,
                        diagnostics: DiagnosticEngine) throws -> MIRModule {
        let lowering = MIRLowering(typeCheckResult: input)
        return lowering.lower()
    }
}

/// Phase 7: MIR Optimization — MIR → Optimized MIR
public struct MIROptimizePhase: CompilerPhase {
    public typealias Input = MIRModule
    public typealias Output = MIRModule

    public let name = "MIR Optimization"

    public init() {}

    public func execute(input: MIRModule, context: CompilationContext,
                        diagnostics: DiagnosticEngine) throws -> MIRModule {
        let optimizer = MIROptimizer()
        return optimizer.optimize(input)
    }
}

/// Phase 8: LLVM IR Emission — Optimized MIR → LLVM IR text
public struct LLVMEmitPhase: CompilerPhase {
    public typealias Input = MIRModule
    public typealias Output = String // LLVM IR text

    public let name = "LLVM Code Generation"

    public init() {}

    public func execute(input: MIRModule, context: CompilationContext,
                        diagnostics: DiagnosticEngine) throws -> String {
        let codeGen = LLVMCodeGen()
        return codeGen.emit(module: input)
    }
}

// MARK: - Compiler Pipeline

/// Orchestrates the compilation phases with artifact capture and contract enforcement.
///
/// DO-330 6.3.2: The tool shall execute each component in the correct order
/// and shall verify that each component completes successfully before
/// proceeding to the next.
public final class CompilerPipeline {
    private let context: CompilationContext
    private let diagnostics: DiagnosticEngine
    private var artifacts: [PhaseArtifact] = []
    private let verbose: Bool

    public init(context: CompilationContext, diagnostics: DiagnosticEngine,
                verbose: Bool = true) {
        self.context = context
        self.diagnostics = diagnostics
        self.verbose = verbose
    }

    /// Run a single phase, capturing its artifact.
    ///
    /// - Parameters:
    ///   - phase: The phase to execute
    ///   - input: The typed input from the previous phase
    /// - Returns: The typed output for the next phase
    public func run<P: CompilerPhase>(_ phase: P, input: P.Input) throws -> P.Output {
        if verbose {
            print("  \(phase.name)...", terminator: "")
            fflush(stdout)
        }

        let diagCountBefore = diagnostics.diagnostics.count
        let start = CFAbsoluteTimeGetCurrent()

        let output = try phase.execute(input: input, context: context, diagnostics: diagnostics)

        let duration = CFAbsoluteTimeGetCurrent() - start
        let diagCountAfter = diagnostics.diagnostics.count

        let artifact = PhaseArtifact(
            phaseName: phase.name,
            duration: duration,
            diagnosticCount: diagCountAfter - diagCountBefore,
            summary: "\(phase.name) completed in \(String(format: "%.3f", duration))s"
        )
        artifacts.append(artifact)

        if verbose {
            print(" done")
        }

        return output
    }

    /// Get all captured phase artifacts (for audit trail).
    public var phaseArtifacts: [PhaseArtifact] { artifacts }

    /// Export audit report as JSON to the given path.
    /// DO-330 6.3.2: Tool shall produce auditable records.
    public func exportAuditReport(to path: String) throws {
        let report: [String: Any] = [
            "compilerVersion": context.compilerVersion,
            "buildTimestamp": context.buildTimestamp,
            "sourceFile": context.fileName,
            "safetyLevel": context.safetyLevel?.rawValue ?? "none",
            "phases": artifacts.map { $0.toJSON() },
            "totalDurationSeconds": artifacts.reduce(0.0) { $0 + $1.duration },
            "phaseCount": artifacts.count,
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        try jsonData.write(to: URL(fileURLWithPath: path))
    }

    /// Print an audit summary of all phases that have run.
    public func printAuditTrail() {
        print("\n  --- Compilation Audit Trail ---")
        for (i, artifact) in artifacts.enumerated() {
            print("  Phase \(i + 1): \(artifact.phaseName) " +
                  "[\(String(format: "%.3f", artifact.duration))s, " +
                  "\(artifact.diagnosticCount) diagnostics]")
        }
        let total = artifacts.reduce(0.0) { $0 + $1.duration }
        print("  Total: \(String(format: "%.3f", total))s across \(artifacts.count) phases")
        print("  ---")
    }

    /// Execute the standard Rockit native compilation pipeline.
    ///
    /// Pipeline:
    ///   Source → Lex → Parse → ImportResolve → TypeCheck → [Safety] → MIRLower → MIROptimize → LLVMEmit
    ///
    /// Each phase boundary is a typed contract. Each phase is independently
    /// testable. Artifacts are captured for DO-178C traceability.
    public func compileToLLVMIR(source: String) throws -> String {
        // Phase 1: Lex
        let tokens = try run(LexPhase(), input: source)

        // Phase 2: Parse
        let ast = try run(ParsePhase(), input: tokens)

        // Phase 3: Import Resolution
        let mergedAST = try run(ImportPhase(), input: ast)

        // Phase 4: Type Check
        let typeResult = try run(TypeCheckPhase(), input: mergedAST)

        // Phase 5: Safety Verification (conditional)
        let verifiedResult = try run(SafetyPhase(), input: typeResult)

        // Phase 6: MIR Lowering
        let mir = try run(MIRLowerPhase(), input: verifiedResult)

        // Phase 7: MIR Optimization
        let optimizedMIR = try run(MIROptimizePhase(), input: mir)

        // Phase 8: LLVM Code Generation
        let llvmIR = try run(LLVMEmitPhase(), input: optimizedMIR)

        // DO-330 6.3.2: Persist audit trail if requested
        if let auditPath = context.auditOutputPath {
            try exportAuditReport(to: auditPath)
            printAuditTrail()
        }

        return llvmIR
    }
}

// MARK: - Pipeline Errors

public enum CompilerPipelineError: Error, CustomStringConvertible {
    case phaseErrors(String, Int)
    case safetyViolations(SafetyLevel, [SafetyViolation])
    case linkFailed(String)

    public var description: String {
        switch self {
        case .phaseErrors(let phase, let count):
            return "\(phase): \(count) error(s)"
        case .safetyViolations(let level, let violations):
            var s = "Safety verification FAILED for \(level.displayName): \(violations.count) violation(s)"
            for v in violations {
                s += "\n  \(v.fullDescription)"
            }
            return s
        case .linkFailed(let detail):
            return "Link failed: \(detail)"
        }
    }
}
