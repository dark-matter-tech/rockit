// CompilerPipelineTests.swift
// RockitKit — Rockit Language Compiler
// Copyright © 2026 Dark Matter Tech. All rights reserved.

import XCTest
@testable import RockitKit

final class CompilerPipelineTests: XCTestCase {

    // MARK: - Helpers

    private func compilePipeline(_ source: String, safetyLevel: SafetyLevel? = nil,
                                  auditPath: String? = nil) throws -> (String, CompilerPipeline) {
        let diagnostics = DiagnosticEngine()
        let context = CompilationContext(
            fileName: "test.rok",
            safetyLevel: safetyLevel,
            libPaths: [],
            auditOutputPath: auditPath
        )
        let pipeline = CompilerPipeline(context: context, diagnostics: diagnostics, verbose: false)
        let ir = try pipeline.compileToLLVMIR(source: source)
        return (ir, pipeline)
    }

    // MARK: - Phase Artifacts

    func testPhaseArtifactsPopulated() throws {
        let (_, pipeline) = try compilePipeline("fun main(): Unit { }")
        let artifacts = pipeline.phaseArtifacts
        // Should have 8 phases: Lex, Parse, Import, TypeCheck, Safety, MIR, Optimize, LLVM
        XCTAssertEqual(artifacts.count, 8)
        XCTAssertEqual(artifacts[0].phaseName, "Lexer")
        XCTAssertEqual(artifacts[1].phaseName, "Parser")
        XCTAssertEqual(artifacts[2].phaseName, "Import Resolution")
        XCTAssertEqual(artifacts[3].phaseName, "Type Checker")
        XCTAssertEqual(artifacts[4].phaseName, "Safety Verification")
        XCTAssertEqual(artifacts[5].phaseName, "MIR Lowering")
        XCTAssertEqual(artifacts[6].phaseName, "MIR Optimization")
        XCTAssertEqual(artifacts[7].phaseName, "LLVM Code Generation")
    }

    func testPhaseArtifactDurationsPositive() throws {
        let (_, pipeline) = try compilePipeline("""
        fun add(a: Int, b: Int): Int { return a + b }
        fun main(): Unit { println(add(1, 2)) }
        """)
        for artifact in pipeline.phaseArtifacts {
            XCTAssertGreaterThanOrEqual(artifact.duration, 0.0,
                "\(artifact.phaseName) duration should be non-negative")
        }
    }

    // MARK: - Audit Report

    func testExportAuditReportProducesValidJSON() throws {
        let tempDir = NSTemporaryDirectory()
        let auditPath = (tempDir as NSString).appendingPathComponent("test_audit_\(ProcessInfo.processInfo.processIdentifier).json")
        defer { try? FileManager.default.removeItem(atPath: auditPath) }

        let (_, _) = try compilePipeline("fun main(): Unit { }", auditPath: auditPath)

        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: auditPath), "Audit JSON should be written")

        // Verify valid JSON with expected fields
        let data = try Data(contentsOf: URL(fileURLWithPath: auditPath))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(json["compilerVersion"])
        XCTAssertNotNil(json["buildTimestamp"])
        XCTAssertEqual(json["sourceFile"] as? String, "test.rok")
        XCTAssertEqual(json["safetyLevel"] as? String, "none")
        XCTAssertNotNil(json["phases"])
        let phases = json["phases"] as! [[String: Any]]
        XCTAssertEqual(phases.count, 8)
    }

    func testAuditReportIncludesSafetyLevel() throws {
        let tempDir = NSTemporaryDirectory()
        let auditPath = (tempDir as NSString).appendingPathComponent("test_audit_safety_\(ProcessInfo.processInfo.processIdentifier).json")
        defer { try? FileManager.default.removeItem(atPath: auditPath) }

        // DAL E allows everything, so this should pass
        let (_, _) = try compilePipeline("fun main(): Unit { }", safetyLevel: .dalE, auditPath: auditPath)

        let data = try Data(contentsOf: URL(fileURLWithPath: auditPath))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["safetyLevel"] as? String, "dal-e")
    }

    // MARK: - PhaseArtifact JSON

    func testPhaseArtifactToJSON() {
        let artifact = PhaseArtifact(phaseName: "Lexer", duration: 0.005,
                                      diagnosticCount: 0, summary: "Lexer completed")
        let json = artifact.toJSON()
        XCTAssertEqual(json["phase"] as? String, "Lexer")
        XCTAssertEqual(json["diagnosticCount"] as? Int, 0)
    }

    // MARK: - CompilationContext

    func testContextDefaults() {
        let ctx = CompilationContext(fileName: "test.rok")
        XCTAssertEqual(ctx.compilerVersion, "0.1.0-alpha")
        XCTAssertFalse(ctx.buildTimestamp.isEmpty)
        XCTAssertNil(ctx.auditOutputPath)
    }

    // MARK: - End-to-End

    func testPipelineProducesValidLLVMIR() throws {
        let (ir, _) = try compilePipeline("""
        fun add(a: Int, b: Int): Int { return a + b }
        fun main(): Unit { println(add(1, 2)) }
        """)
        XCTAssertTrue(ir.contains("; Rockit LLVM IR"))
        XCTAssertTrue(ir.contains("define i32 @main"))
    }
}
