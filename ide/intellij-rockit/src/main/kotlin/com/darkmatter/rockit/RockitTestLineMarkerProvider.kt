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
 * Adds Xcode-style gutter icons for @Test functions and per-assertion results.
 *
 * Function-level icons:
 * - Green play icon: test not yet run (click to run)
 * - Yellow circle: test is running
 * - Green checkmark: test passed
 * - Red X: test failed
 *
 * Assertion-level icons (after running with --detailed):
 * - Green checkmark: assertion passed
 * - Red X: assertion failed (with failure message in tooltip)
 */
class RockitTestLineMarkerProvider : LineMarkerProvider {

    enum class TestState { RUNNING, PASSED, FAILED }

    data class AssertionResult(val passed: Boolean, val message: String = "")

    companion object {
        // Cache: filePath -> (testFunctionName -> state)
        val testStates = ConcurrentHashMap<String, ConcurrentHashMap<String, TestState>>()
        // Cache: filePath -> (className -> state) for class-level aggregation
        val classStates = ConcurrentHashMap<String, ConcurrentHashMap<String, TestState>>()
        // Cache: filePath -> (testFunctionName -> list of per-assertion results)
        val assertionResults = ConcurrentHashMap<String, ConcurrentHashMap<String, List<AssertionResult>>>()
        private const val NOTIFICATION_GROUP = "Rockit Test Runner"

        val ASSERT_FUNCTIONS = setOf(
            "assert", "assertTrue", "assertFalse", "assertEquals", "assertEqualsStr",
            "assertNotEquals", "assertGreaterThan", "assertLessThan",
            "assertStringContains", "assertStartsWith", "assertEndsWith", "fail"
        )
    }

    override fun getLineMarkerInfo(element: PsiElement): LineMarkerInfo<*>? {
        val type = element.node.elementType

        // @Test function play buttons
        if (type == RockitTokenTypes.KW_FUN) {
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

        // @Test class play buttons — show on class keyword if body contains @Test
        if (type == RockitTokenTypes.KW_CLASS) {
            val className = findClassName(element) ?: return null
            val filePath = element.containingFile.virtualFile?.path ?: return null

            // Scan forward from the class keyword to check if its body contains @Test
            if (!classContainsTests(element)) return null

            val classIcon = getClassIcon(filePath, className)
            val classTooltip = getClassTooltip(filePath, className)

            return LineMarkerInfo(
                element,
                element.textRange,
                classIcon,
                { classTooltip },
                { _, elt -> runTestClass(elt, filePath, className) },
                GutterIconRenderer.Alignment.CENTER,
                { classTooltip }
            )
        }

        // Per-assertion result icons
        if (type == RockitTokenTypes.IDENTIFIER || type == RockitTokenTypes.FUNCTION_CALL) {
            val name = element.text
            if (name in ASSERT_FUNCTIONS) {
                return getAssertionLineMarker(element, name)
            }
        }

        return null
    }

    private fun getAssertionLineMarker(element: PsiElement, assertName: String): LineMarkerInfo<*>? {
        val filePath = element.containingFile.virtualFile?.path ?: return null
        val fileAssertions = assertionResults[filePath] ?: return null

        val document = PsiDocumentManager.getInstance(element.project)
            .getDocument(element.containingFile) ?: return null

        // Find which @Test function this assertion is inside
        val elementLine = document.getLineNumber(element.textOffset)
        val testInfo = findEnclosingTestFunction(document, elementLine) ?: return null
        val (testName, testFunBodyLine) = testInfo

        val results = fileAssertions[testName] ?: return null

        // Count assertion calls from function body start to this element's line
        val assertionIndex = getAssertionIndex(document, testFunBodyLine, elementLine)
        if (assertionIndex < 0 || assertionIndex >= results.size) return null

        val result = results[assertionIndex]
        val icon = if (result.passed)
            AllIcons.RunConfigurations.TestState.Green2
        else
            AllIcons.RunConfigurations.TestState.Red2
        val tooltip = if (result.passed)
            "$assertName passed"
        else
            "$assertName failed: ${result.message}"

        return LineMarkerInfo(
            element,
            element.textRange,
            icon,
            { tooltip },
            null,
            GutterIconRenderer.Alignment.CENTER,
            { tooltip }
        )
    }

    /**
     * Walk backwards from elementLine to find the enclosing @Test function.
     * Returns (testFunctionName, bodyStartLine) or null.
     */
    private fun findEnclosingTestFunction(
        document: com.intellij.openapi.editor.Document,
        elementLine: Int
    ): Pair<String, Int>? {
        // Scan backwards for a `fun` keyword line
        for (line in elementLine downTo 0) {
            val lineStart = document.getLineStartOffset(line)
            val lineEnd = document.getLineEndOffset(line)
            val lineText = document.getText(TextRange(lineStart, lineEnd)).trim()

            // Match "fun functionName(" pattern
            val funMatch = Regex("""^fun\s+(\w+)\s*\(""").find(lineText) ?: continue
            val funcName = funMatch.groupValues[1]

            // Check if this function has @Test annotation above it
            for (prevLine in (line - 1) downTo maxOf(0, line - 3)) {
                val prevStart = document.getLineStartOffset(prevLine)
                val prevEnd = document.getLineEndOffset(prevLine)
                val prevText = document.getText(TextRange(prevStart, prevEnd)).trim()
                if (prevText == "@Test") {
                    // Body starts on the line after the fun declaration (after opening brace)
                    return Pair(funcName, line + 1)
                }
                if (prevText.isNotEmpty() && !prevText.startsWith("@")) break
            }

            // Also check if @Test is on the same line before fun
            if (lineText.startsWith("@Test")) {
                return Pair(funcName, line + 1)
            }

            // If we hit a non-@Test function, stop searching
            return null
        }
        return null
    }

    /**
     * Count how many assertion calls appear on lines [bodyStartLine, elementLine)
     * to determine this assertion's index in the recorded results.
     */
    private fun getAssertionIndex(
        document: com.intellij.openapi.editor.Document,
        bodyStartLine: Int,
        elementLine: Int
    ): Int {
        var index = 0
        for (lineNum in bodyStartLine until elementLine) {
            if (lineNum >= document.lineCount) break
            val lineStart = document.getLineStartOffset(lineNum)
            val lineEnd = document.getLineEndOffset(lineNum)
            val lineText = document.getText(TextRange(lineStart, lineEnd)).trim()
            if (ASSERT_FUNCTIONS.any { lineText.startsWith("$it(") || lineText.startsWith("$it (") }) {
                index++
            }
        }
        return index
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
     * Find the rockit binary. Checks well-known locations before falling back to PATH.
     */
    private fun findRockitBinary(workDir: File?): String {
        // 1. ~/.local/bin/rockit (standard user install)
        val home = System.getProperty("user.home")
        val localBin = File(home, ".local/bin/rockit")
        if (localBin.exists() && localBin.canExecute()) return localBin.absolutePath

        // 2. Project .build/debug/rockit (development build)
        if (workDir != null) {
            val debugBuild = File(workDir, ".build/debug/rockit")
            if (debugBuild.exists() && debugBuild.canExecute()) return debugBuild.absolutePath
        }

        // 3. /usr/local/bin/rockit
        val usrLocal = File("/usr/local/bin/rockit")
        if (usrLocal.exists() && usrLocal.canExecute()) return usrLocal.absolutePath

        // 4. Fall back to PATH
        return "rockit"
    }

    /**
     * Extract the class name from a KW_CLASS element by finding the next IDENTIFIER sibling.
     */
    private fun findClassName(classElement: PsiElement): String? {
        var sibling = classElement.nextSibling
        while (sibling != null) {
            val type = sibling.node.elementType
            if (type == RockitTokenTypes.IDENTIFIER) {
                return sibling.text
            }
            if (type != RockitTokenTypes.WHITE_SPACE && type != RockitTokenTypes.NEWLINE) break
            sibling = sibling.nextSibling
        }
        return null
    }

    /**
     * Check if a class body contains any @Test annotations by scanning the text
     * from the class keyword to the matching closing brace.
     */
    private fun classContainsTests(classElement: PsiElement): Boolean {
        val document = PsiDocumentManager.getInstance(classElement.project)
            .getDocument(classElement.containingFile) ?: return false
        val startOffset = classElement.textOffset
        val text = document.text
        // Find the opening brace of the class
        var idx = startOffset
        var depth = 0
        while (idx < text.length) {
            if (text[idx] == '{') {
                depth++
                break
            }
            idx++
        }
        if (depth == 0) return false
        // Scan the class body for @Test
        val bodyStart = idx
        while (idx < text.length) {
            if (text[idx] == '{') depth++
            else if (text[idx] == '}') {
                depth--
                if (depth == 0) break
            }
            idx++
        }
        val bodyText = text.substring(bodyStart, minOf(idx + 1, text.length))
        return bodyText.contains("@Test")
    }

    private fun getClassIcon(filePath: String, className: String): Icon {
        val states = classStates[filePath] ?: return AllIcons.RunConfigurations.TestState.Run
        return when (states[className]) {
            TestState.RUNNING -> AllIcons.RunConfigurations.TestState.Yellow2
            TestState.PASSED -> AllIcons.RunConfigurations.TestState.Green2
            TestState.FAILED -> AllIcons.RunConfigurations.TestState.Red2
            null -> AllIcons.RunConfigurations.TestState.Run
        }
    }

    private fun getClassTooltip(filePath: String, className: String): String {
        val states = classStates[filePath] ?: return "Run all tests in $className"
        return when (states[className]) {
            TestState.RUNNING -> "Running $className tests..."
            TestState.PASSED -> "$className — all tests passed"
            TestState.FAILED -> "$className — some tests failed"
            null -> "Run all tests in $className"
        }
    }

    /**
     * Run all @Test methods in a class by invoking `rockit test <file> --filter <ClassName>`.
     */
    private fun runTestClass(element: PsiElement, filePath: String, className: String) {
        val project = element.project

        // Set class to RUNNING
        val fileClassStates = classStates.getOrPut(filePath) { ConcurrentHashMap() }
        fileClassStates[className] = TestState.RUNNING
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

                val rockitBin = findRockitBinary(workDir)
                val commandLine = GeneralCommandLine(
                    rockitBin, "test", filePath, "--filter", className
                ).withParentEnvironmentType(GeneralCommandLine.ParentEnvironmentType.CONSOLE)
                if (workDir != null) {
                    commandLine.withWorkDirectory(workDir)
                }

                val process = commandLine.createProcess()
                val stderrFuture = java.util.concurrent.CompletableFuture.supplyAsync {
                    process.errorStream.bufferedReader().readText()
                }
                val output = process.inputStream.bufferedReader().readText()
                stderrFuture.get()
                val finished = process.waitFor(30, TimeUnit.SECONDS)

                if (!finished) {
                    process.destroyForcibly()
                    notify(project, "$className tests timed out", NotificationType.WARNING)
                    fileClassStates.remove(className)
                    return@executeOnPooledThread
                }

                // Parse results: check for any FAIL lines for this class
                val passPattern = Regex("""PASS\s+\S+::${Regex.escape(className)}::(\w+)""")
                val failPattern = Regex("""FAIL\s+\S+::${Regex.escape(className)}::(\w+)""")
                var anyFailed = false
                var anyFound = false
                val fileStates = testStates.getOrPut(filePath) { ConcurrentHashMap() }

                for (line in output.lines()) {
                    passPattern.find(line)?.let { match ->
                        val methodName = match.groupValues[1]
                        fileStates[methodName] = TestState.PASSED
                        anyFound = true
                    }
                    failPattern.find(line)?.let { match ->
                        val methodName = match.groupValues[1]
                        fileStates[methodName] = TestState.FAILED
                        anyFailed = true
                        anyFound = true
                    }
                }

                if (anyFound) {
                    fileClassStates[className] = if (anyFailed) TestState.FAILED else TestState.PASSED
                    val msg = if (anyFailed) "$className — some tests failed" else "$className — all tests passed"
                    notify(project, msg, if (anyFailed) NotificationType.WARNING else NotificationType.INFORMATION)
                } else {
                    fileClassStates.remove(className)
                    notify(project, "$className: no test results parsed", NotificationType.WARNING)
                }

                ApplicationManager.getApplication().invokeLater {
                    DaemonCodeAnalyzer.getInstance(project).restart()
                }
            } catch (e: Exception) {
                notify(project, "Failed to run $className tests: ${e.message}", NotificationType.ERROR)
                fileClassStates.remove(className)
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

                val rockitBin = findRockitBinary(workDir)
                val commandLine = GeneralCommandLine(
                    rockitBin, "test", filePath, "--filter", testName, "--detailed"
                ).withParentEnvironmentType(GeneralCommandLine.ParentEnvironmentType.CONSOLE)
                if (workDir != null) {
                    commandLine.withWorkDirectory(workDir)
                }

                val process = commandLine.createProcess()
                // Read stdout and stderr concurrently to avoid deadlocks
                val stderrFuture = java.util.concurrent.CompletableFuture.supplyAsync {
                    process.errorStream.bufferedReader().readText()
                }
                val output = process.inputStream.bufferedReader().readText()
                val stderr = stderrFuture.get()
                val finished = process.waitFor(30, TimeUnit.SECONDS)

                if (!finished) {
                    process.destroyForcibly()
                    notify(project, "$testName timed out", NotificationType.WARNING)
                    fileStates.remove(testName)
                    return@executeOnPooledThread
                }

                // Parse per-assertion results from __PROBE_RESULTS_BEGIN/END block
                val probeResults = mutableListOf<AssertionResult>()
                var inProbeBlock = false
                for (line in output.lines()) {
                    if (line.trim() == "__PROBE_RESULTS_BEGIN") { inProbeBlock = true; continue }
                    if (line.trim() == "__PROBE_RESULTS_END") { inProbeBlock = false; continue }
                    if (inProbeBlock && line.trim().isNotEmpty()) {
                        val trimmed = line.trim()
                        if (trimmed == "P") {
                            probeResults.add(AssertionResult(passed = true))
                        } else if (trimmed.startsWith("F:")) {
                            probeResults.add(AssertionResult(passed = false, message = trimmed.removePrefix("F:")))
                        }
                    }
                }

                // Store assertion results
                if (probeResults.isNotEmpty()) {
                    val fileAssertions = assertionResults.getOrPut(filePath) { ConcurrentHashMap() }
                    fileAssertions[testName] = probeResults
                }

                // Parse overall result for this specific test
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
                            val errorMsg = line.substringAfter(" — ", "").take(200)
                            notify(project, "$testName failed: $errorMsg", NotificationType.WARNING)
                            found = true
                        }
                    }
                }

                if (!found) {
                    // Check for compilation error format (no ::testName in output)
                    val compileError = output.lines().any { it.contains("compilation error") }
                    if (compileError) {
                        fileStates[testName] = TestState.FAILED
                        val errors = output.lines()
                            .filter { it.contains("error:") }
                            .take(3)
                            .joinToString("\n")
                        notify(project, "$testName failed to compile:\n$errors", NotificationType.WARNING)
                    } else {
                        fileStates.remove(testName)
                        val debugMsg = buildString {
                            append("$testName: no result parsed.\n")
                            append("Binary: $rockitBin\n")
                            if (output.isNotBlank()) append("stdout: ${output.take(300)}\n")
                            if (stderr.isNotBlank()) append("stderr: ${stderr.take(300)}")
                        }
                        notify(project, debugMsg, NotificationType.WARNING)
                    }
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
