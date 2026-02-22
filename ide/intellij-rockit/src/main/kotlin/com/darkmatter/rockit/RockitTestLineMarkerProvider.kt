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
            { _, elt -> runTest(elt, filePath, testFunctionName) },
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

    private fun runTest(element: PsiElement, filePath: String, testName: String) {
        val project = element.project

        // Set this test to RUNNING and refresh gutters immediately
        val fileStates = testStates.getOrPut(filePath) { ConcurrentHashMap() }
        fileStates[testName] = TestState.RUNNING
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

                val commandLine = GeneralCommandLine(
                    "rockit", "test", filePath, "--filter", testName
                ).withParentEnvironmentType(GeneralCommandLine.ParentEnvironmentType.CONSOLE)
                if (workDir != null) {
                    commandLine.withWorkDirectory(workDir)
                }

                val process = commandLine.createProcess()
                val output = process.inputStream.bufferedReader().readText()
                val stderr = process.errorStream.bufferedReader().readText()
                val finished = process.waitFor(30, TimeUnit.SECONDS)

                if (!finished) {
                    process.destroyForcibly()
                    notify(project, "$testName timed out", NotificationType.WARNING)
                    fileStates.remove(testName)
                    return@executeOnPooledThread
                }

                // Parse result for this specific test
                val passPattern = Regex("""PASS\s+\S+::(\w+)""")
                val failPattern = Regex("""FAIL\s+\S+::(\w+)""")
                var found = false

                for (line in output.lines()) {
                    passPattern.find(line)?.let { match ->
                        if (match.groupValues[1] == testName) {
                            fileStates[testName] = TestState.PASSED
                            notify(project, "$testName passed", NotificationType.INFORMATION)
                            found = true
                        }
                    }
                    failPattern.find(line)?.let { match ->
                        if (match.groupValues[1] == testName) {
                            fileStates[testName] = TestState.FAILED
                            // Extract error message after " — "
                            val errorMsg = line.substringAfter(" — ", "").take(200)
                            notify(project, "$testName failed: $errorMsg", NotificationType.WARNING)
                            found = true
                        }
                    }
                }

                if (!found) {
                    fileStates.remove(testName)
                    val debugMsg = buildString {
                        append("$testName: no result parsed.\n")
                        if (output.isNotBlank()) append("stdout: ${output.take(300)}\n")
                        if (stderr.isNotBlank()) append("stderr: ${stderr.take(300)}")
                    }
                    notify(project, debugMsg, NotificationType.WARNING)
                }

                // Refresh gutter icons
                ApplicationManager.getApplication().invokeLater {
                    DaemonCodeAnalyzer.getInstance(project).restart()
                }
            } catch (e: Exception) {
                notify(project, "Failed to run $testName: ${e.message}", NotificationType.ERROR)
                fileStates.remove(testName)
            }
        }
    }
}
