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
 * - Yellow circle: test is running
 * - Green checkmark: test passed
 * - Red X: test failed
 */
class RockitTestLineMarkerProvider : LineMarkerProvider {

    enum class TestState { RUNNING, PASSED, FAILED }

    companion object {
        // Cache: filePath -> (testFunctionName -> state)
        val testStates = ConcurrentHashMap<String, ConcurrentHashMap<String, TestState>>()
        // Track which files are currently running tests (prevent double-runs)
        val runningFiles = ConcurrentHashMap.newKeySet<String>()
        private const val NOTIFICATION_GROUP = "Rockit Test Runner"
    }

    override fun getLineMarkerInfo(element: PsiElement): LineMarkerInfo<*>? {
        if (element.node.elementType != RockitTokenTypes.KW_FUN) return null

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

    private fun findTestFunctionName(funElement: PsiElement): String? {
        val document = PsiDocumentManager.getInstance(funElement.project)
            .getDocument(funElement.containingFile) ?: return null
        val funLine = document.getLineNumber(funElement.textOffset)

        for (prevLine in (funLine - 1) downTo maxOf(0, funLine - 3)) {
            val lineStart = document.getLineStartOffset(prevLine)
            val lineEnd = document.getLineEndOffset(prevLine)
            val lineText = document.getText(TextRange(lineStart, lineEnd)).trim()
            if (lineText == "@Test") return extractFunctionName(funElement)
            if (lineText.isNotEmpty() && !lineText.startsWith("@")) break
        }

        val funLineStart = document.getLineStartOffset(funLine)
        val textBeforeFun = document.getText(TextRange(funLineStart, funElement.textOffset)).trim()
        if (textBeforeFun == "@Test") return extractFunctionName(funElement)

        return null
    }

    private fun extractFunctionName(funElement: PsiElement): String? {
        var sibling = funElement.nextSibling
        while (sibling != null) {
            val type = sibling.node.elementType
            if (type == RockitTokenTypes.IDENTIFIER || type == RockitTokenTypes.FUNCTION_CALL) {
                return sibling.text
            }
            if (type != RockitTokenTypes.WHITE_SPACE && type != RockitTokenTypes.NEWLINE) break
            sibling = sibling.nextSibling
        }
        return null
    }

    private fun getIcon(filePath: String, testFunctionName: String): Icon {
        val states = testStates[filePath] ?: return AllIcons.RunConfigurations.TestState.Run
        return when (states[testFunctionName]) {
            TestState.RUNNING -> AllIcons.RunConfigurations.TestState.Yellow2
            TestState.PASSED -> AllIcons.RunConfigurations.TestState.Green2
            TestState.FAILED -> AllIcons.RunConfigurations.TestState.Red2
            null -> AllIcons.RunConfigurations.TestState.Run
        }
    }

    private fun getTooltip(filePath: String, testFunctionName: String): String {
        val states = testStates[filePath] ?: return "Run $testFunctionName"
        return when (states[testFunctionName]) {
            TestState.RUNNING -> "Running $testFunctionName..."
            TestState.PASSED -> "$testFunctionName passed"
            TestState.FAILED -> "$testFunctionName failed"
            null -> "Run $testFunctionName"
        }
    }

    private fun notify(project: Project, message: String, type: NotificationType) {
        ApplicationManager.getApplication().invokeLater {
            try {
                NotificationGroupManager.getInstance()
                    .getNotificationGroup(NOTIFICATION_GROUP)
                    .createNotification(message, type)
                    .notify(project)
            } catch (_: Exception) {
                com.intellij.openapi.ui.Messages.showInfoMessage(project, message, "Rockit Tests")
            }
        }
    }

    /**
     * Collect all @Test function names in the file by scanning the document text.
     */
    private fun collectAllTestNames(element: PsiElement): List<String> {
        val document = PsiDocumentManager.getInstance(element.project)
            .getDocument(element.containingFile) ?: return emptyList()
        val text = document.text
        val names = mutableListOf<String>()
        val pattern = Regex("""@Test\s+fun\s+(\w+)""")
        for (match in pattern.findAll(text)) {
            names.add(match.groupValues[1])
        }
        return names
    }

    private fun runTest(element: PsiElement, filePath: String) {
        // Prevent double-runs
        if (!runningFiles.add(filePath)) return

        val project = element.project

        // Set all tests in this file to RUNNING and refresh gutters immediately
        val allTestNames = collectAllTestNames(element)
        val fileStates = testStates.getOrPut(filePath) { ConcurrentHashMap() }
        for (name in allTestNames) {
            fileStates[name] = TestState.RUNNING
        }
        ApplicationManager.getApplication().invokeLater {
            DaemonCodeAnalyzer.getInstance(project).restart()
        }

        ApplicationManager.getApplication().executeOnPooledThread {
            try {
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
                    // Reset running states back to play button
                    testStates.remove(filePath)
                    return@executeOnPooledThread
                }

                // Parse results
                val passPattern = Regex("""PASS\s+\S+::(\w+)""")
                val failPattern = Regex("""FAIL\s+\S+::(\w+)""")
                var passed = 0
                var failed = 0

                for (line in output.lines()) {
                    passPattern.find(line)?.let { match ->
                        fileStates[match.groupValues[1]] = TestState.PASSED
                        passed++
                    }
                    failPattern.find(line)?.let { match ->
                        fileStates[match.groupValues[1]] = TestState.FAILED
                        failed++
                    }
                }

                // Any test still in RUNNING state had no output — mark unknown
                for ((name, state) in fileStates) {
                    if (state == TestState.RUNNING) {
                        fileStates.remove(name)
                    }
                }

                if (passed + failed > 0) {
                    val msg = if (failed == 0) "$passed test(s) passed" else "$passed passed, $failed failed"
                    val type = if (failed == 0) NotificationType.INFORMATION else NotificationType.WARNING
                    notify(project, msg, type)
                } else {
                    val debugMsg = buildString {
                        append("No test results parsed.\n")
                        if (output.isNotBlank()) append("stdout: ${output.take(500)}\n")
                        if (stderr.isNotBlank()) append("stderr: ${stderr.take(500)}\n")
                        append("exit code: ${process.exitValue()}")
                    }
                    notify(project, debugMsg, NotificationType.WARNING)
                }

                // Refresh gutter icons with final results
                ApplicationManager.getApplication().invokeLater {
                    DaemonCodeAnalyzer.getInstance(project).restart()
                }
            } catch (e: Exception) {
                notify(project, "Failed to run tests: ${e.message}", NotificationType.ERROR)
                testStates.remove(filePath)
            } finally {
                runningFiles.remove(filePath)
            }
        }
    }
}
