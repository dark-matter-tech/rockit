package com.darkmatter.rockit

import com.intellij.codeInsight.daemon.DaemonCodeAnalyzer
import com.intellij.codeInsight.daemon.LineMarkerInfo
import com.intellij.codeInsight.daemon.LineMarkerProvider
import com.intellij.execution.configurations.GeneralCommandLine
import com.intellij.icons.AllIcons
import com.intellij.notification.NotificationGroupManager
import com.intellij.notification.NotificationType
import com.intellij.openapi.application.ApplicationManager
import com.intellij.openapi.editor.markup.GutterIconRenderer
import com.intellij.openapi.project.Project
import com.intellij.openapi.util.TextRange
import com.intellij.psi.PsiDocumentManager
import com.intellij.psi.PsiElement
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit
import javax.swing.Icon

/**
 * Adds Xcode-style gutter play buttons next to @Test functions.
 *
 * - Green play icon: test not yet run (click to run)
 * - Green checkmark: test passed
 * - Red X: test failed
 *
 * Clicking the play button runs `rockit test <file>` and updates
 * all test icons in the file with pass/fail results.
 */
class RockitTestLineMarkerProvider : LineMarkerProvider {

    companion object {
        // Cache: filePath -> (testFunctionName -> passed)
        val testResults = ConcurrentHashMap<String, ConcurrentHashMap<String, Boolean>>()
        private const val NOTIFICATION_GROUP = "Rockit Test Runner"
    }

    override fun getLineMarkerInfo(element: PsiElement): LineMarkerInfo<*>? {
        // Only process 'fun' keyword tokens
        if (element.node.elementType != RockitTokenTypes.KW_FUN) return null

        // Check if this function has a @Test annotation
        val testFunctionName = findTestFunctionName(element) ?: return null
        val filePath = element.containingFile.virtualFile?.path ?: return null

        val icon = getIcon(filePath, testFunctionName)
        val tooltip = getTooltip(filePath, testFunctionName)

        return LineMarkerInfo(
            element,
            element.textRange,
            icon,
            { tooltip },
            { _, elt -> runTest(elt, filePath) },
            GutterIconRenderer.Alignment.CENTER,
            { tooltip }
        )
    }

    /**
     * Look backward from the 'fun' keyword for a @Test annotation.
     * Returns the function name if found, null otherwise.
     */
    private fun findTestFunctionName(funElement: PsiElement): String? {
        val document = PsiDocumentManager.getInstance(funElement.project)
            .getDocument(funElement.containingFile) ?: return null
        val funLine = document.getLineNumber(funElement.textOffset)

        // Check previous lines for @Test (handles blank lines between annotation and fun)
        for (prevLine in (funLine - 1) downTo maxOf(0, funLine - 3)) {
            val lineStart = document.getLineStartOffset(prevLine)
            val lineEnd = document.getLineEndOffset(prevLine)
            val lineText = document.getText(TextRange(lineStart, lineEnd)).trim()
            if (lineText == "@Test") {
                return extractFunctionName(funElement)
            }
            // Stop if we hit a non-empty, non-annotation line
            if (lineText.isNotEmpty() && !lineText.startsWith("@")) break
        }

        // Also check same line: "@Test fun foo()"
        val funLineStart = document.getLineStartOffset(funLine)
        val textBeforeFun = document.getText(TextRange(funLineStart, funElement.textOffset)).trim()
        if (textBeforeFun == "@Test") {
            return extractFunctionName(funElement)
        }

        return null
    }

    /**
     * Extract the function name from the IDENTIFIER token following 'fun'.
     */
    private fun extractFunctionName(funElement: PsiElement): String? {
        var sibling = funElement.nextSibling
        while (sibling != null) {
            val type = sibling.node.elementType
            if (type == RockitTokenTypes.IDENTIFIER || type == RockitTokenTypes.FUNCTION_CALL) {
                return sibling.text
            }
            // Skip whitespace/newlines only
            if (type != RockitTokenTypes.WHITE_SPACE && type != RockitTokenTypes.NEWLINE) {
                break
            }
            sibling = sibling.nextSibling
        }
        return null
    }

    private fun getIcon(filePath: String, testFunctionName: String): Icon {
        val results = testResults[filePath] ?: return AllIcons.RunConfigurations.TestState.Run
        val passed = results[testFunctionName] ?: return AllIcons.RunConfigurations.TestState.Run
        return if (passed) {
            AllIcons.RunConfigurations.TestState.Green2
        } else {
            AllIcons.RunConfigurations.TestState.Red2
        }
    }

    private fun getTooltip(filePath: String, testFunctionName: String): String {
        val results = testResults[filePath] ?: return "Run $testFunctionName"
        val passed = results[testFunctionName] ?: return "Run $testFunctionName"
        return if (passed) "$testFunctionName passed" else "$testFunctionName failed"
    }

    private fun notify(project: Project, message: String, type: NotificationType) {
        ApplicationManager.getApplication().invokeLater {
            try {
                NotificationGroupManager.getInstance()
                    .getNotificationGroup(NOTIFICATION_GROUP)
                    .createNotification(message, type)
                    .notify(project)
            } catch (_: Exception) {
                // Notification group not registered — fall back to balloon
                com.intellij.openapi.ui.Messages.showInfoMessage(project, message, "Rockit Tests")
            }
        }
    }

    /**
     * Run `rockit test <file>` in a background thread,
     * parse PASS/FAIL output, and refresh gutter icons.
     */
    private fun runTest(element: PsiElement, filePath: String) {
        val project = element.project

        ApplicationManager.getApplication().executeOnPooledThread {
            try {
                // Find the compiler root (directory containing Stage1/stdlib)
                // by walking up from the test file
                var workDir: File? = null
                var dir = File(filePath).parentFile
                while (dir != null) {
                    if (File(dir, "Stage1/stdlib/rockit").exists()) {
                        workDir = dir
                        break
                    }
                    dir = dir.parentFile
                }

                val commandLine = GeneralCommandLine("rockit", "test", filePath)
                    .withParentEnvironmentType(GeneralCommandLine.ParentEnvironmentType.CONSOLE)
                if (workDir != null) {
                    commandLine.withWorkDirectory(workDir)
                }

                val process = commandLine.createProcess()
                val output = process.inputStream.bufferedReader().readText()
                val stderr = process.errorStream.bufferedReader().readText()
                val finished = process.waitFor(30, TimeUnit.SECONDS)

                if (!finished) {
                    process.destroyForcibly()
                    notify(project, "Rockit test timed out after 30s", NotificationType.WARNING)
                    return@executeOnPooledThread
                }

                val exitCode = process.exitValue()

                // Parse PASS/FAIL lines: "  PASS  file.rok::testName" / "  FAIL  file.rok::testName — error"
                val fileResults = testResults.getOrPut(filePath) { ConcurrentHashMap() }
                val passPattern = Regex("""PASS\s+\S+::(\w+)""")
                val failPattern = Regex("""FAIL\s+\S+::(\w+)""")
                var passed = 0
                var failed = 0

                for (line in output.lines()) {
                    passPattern.find(line)?.let { match ->
                        fileResults[match.groupValues[1]] = true
                        passed++
                    }
                    failPattern.find(line)?.let { match ->
                        fileResults[match.groupValues[1]] = false
                        failed++
                    }
                }

                // Show results notification
                if (passed + failed > 0) {
                    val msg = if (failed == 0) {
                        "$passed test(s) passed"
                    } else {
                        "$passed passed, $failed failed"
                    }
                    val type = if (failed == 0) NotificationType.INFORMATION else NotificationType.WARNING
                    notify(project, msg, type)
                } else {
                    // No tests parsed — show raw output for debugging
                    val debugMsg = buildString {
                        append("No test results parsed.\n")
                        if (output.isNotBlank()) append("stdout: ${output.take(500)}\n")
                        if (stderr.isNotBlank()) append("stderr: ${stderr.take(500)}\n")
                        append("exit code: $exitCode")
                    }
                    notify(project, debugMsg, NotificationType.WARNING)
                }

                // Refresh gutter icons on the EDT
                ApplicationManager.getApplication().invokeLater {
                    DaemonCodeAnalyzer.getInstance(project).restart()
                }
            } catch (e: Exception) {
                notify(project, "Failed to run tests: ${e.message}", NotificationType.ERROR)
            }
        }
    }
}
