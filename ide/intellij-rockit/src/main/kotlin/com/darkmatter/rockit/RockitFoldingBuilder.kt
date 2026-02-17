package com.darkmatter.rockit

import com.intellij.lang.ASTNode
import com.intellij.lang.folding.FoldingBuilderEx
import com.intellij.lang.folding.FoldingDescriptor
import com.intellij.openapi.editor.Document
import com.intellij.openapi.util.TextRange
import com.intellij.psi.PsiElement
import com.intellij.psi.PsiFile

class RockitFoldingBuilder : FoldingBuilderEx() {

    override fun buildFoldRegions(root: PsiElement, document: Document, quick: Boolean): Array<FoldingDescriptor> {
        val descriptors = mutableListOf<FoldingDescriptor>()
        val text = document.text

        // Fold brace blocks: { ... }
        foldBraceBlocks(text, document, root, descriptors)

        // Fold block comments: /* ... */
        foldBlockComments(text, document, root, descriptors)

        // Fold import groups
        foldImportGroups(text, document, root, descriptors)

        return descriptors.toTypedArray()
    }

    private fun foldBraceBlocks(
        text: String,
        document: Document,
        root: PsiElement,
        descriptors: MutableList<FoldingDescriptor>
    ) {
        val stack = mutableListOf<Int>()
        var i = 0
        while (i < text.length) {
            val ch = text[i]
            // Skip strings
            if (ch == '"') {
                if (i + 2 < text.length && text[i + 1] == '"' && text[i + 2] == '"') {
                    // Triple-quoted string
                    i += 3
                    while (i + 2 < text.length) {
                        if (text[i] == '"' && text[i + 1] == '"' && text[i + 2] == '"') {
                            i += 3
                            break
                        }
                        i++
                    }
                    continue
                } else {
                    // Single-line string
                    i++
                    while (i < text.length && text[i] != '"' && text[i] != '\n') {
                        if (text[i] == '\\') i++ // skip escape
                        i++
                    }
                    if (i < text.length) i++ // skip closing quote
                    continue
                }
            }
            // Skip line comments
            if (ch == '/' && i + 1 < text.length && text[i + 1] == '/') {
                while (i < text.length && text[i] != '\n') i++
                continue
            }
            // Skip block comments (handled separately for folding)
            if (ch == '/' && i + 1 < text.length && text[i + 1] == '*') {
                i += 2
                var depth = 1
                while (i + 1 < text.length && depth > 0) {
                    if (text[i] == '/' && text[i + 1] == '*') { depth++; i += 2 }
                    else if (text[i] == '*' && text[i + 1] == '/') { depth--; i += 2 }
                    else i++
                }
                continue
            }

            if (ch == '{') {
                stack.add(i)
            } else if (ch == '}' && stack.isNotEmpty()) {
                val openOffset = stack.removeAt(stack.size - 1)
                val closeOffset = i
                // Only fold if the block spans multiple lines
                val startLine = document.getLineNumber(openOffset)
                val endLine = document.getLineNumber(closeOffset)
                if (endLine > startLine) {
                    descriptors.add(
                        FoldingDescriptor(
                            root.node,
                            TextRange(openOffset, closeOffset + 1)
                        )
                    )
                }
            }
            i++
        }
    }

    private fun foldBlockComments(
        text: String,
        document: Document,
        root: PsiElement,
        descriptors: MutableList<FoldingDescriptor>
    ) {
        var i = 0
        while (i + 1 < text.length) {
            if (text[i] == '/' && text[i + 1] == '*') {
                val start = i
                i += 2
                var depth = 1
                while (i + 1 < text.length && depth > 0) {
                    if (text[i] == '/' && text[i + 1] == '*') { depth++; i += 2 }
                    else if (text[i] == '*' && text[i + 1] == '/') { depth--; i += 2 }
                    else i++
                }
                val end = i
                val startLine = document.getLineNumber(start)
                val endLine = document.getLineNumber(end - 1)
                if (endLine > startLine) {
                    descriptors.add(
                        FoldingDescriptor(
                            root.node,
                            TextRange(start, end)
                        )
                    )
                }
            } else {
                i++
            }
        }
    }

    private fun foldImportGroups(
        text: String,
        document: Document,
        root: PsiElement,
        descriptors: MutableList<FoldingDescriptor>
    ) {
        var firstImportLine = -1
        var lastImportLine = -1

        for (line in 0 until document.lineCount) {
            val lineStart = document.getLineStartOffset(line)
            val lineEnd = document.getLineEndOffset(line)
            val lineText = text.substring(lineStart, lineEnd).trim()

            if (lineText.startsWith("import ")) {
                if (firstImportLine == -1) firstImportLine = line
                lastImportLine = line
            } else if (firstImportLine != -1 && lineText.isNotEmpty() && !lineText.startsWith("//")) {
                break
            }
        }

        if (firstImportLine != -1 && lastImportLine > firstImportLine) {
            val start = document.getLineStartOffset(firstImportLine)
            val end = document.getLineEndOffset(lastImportLine)
            descriptors.add(
                FoldingDescriptor(
                    root.node,
                    TextRange(start, end)
                )
            )
        }
    }

    override fun getPlaceholderText(node: ASTNode): String {
        val text = node.text
        return when {
            text.startsWith("/*") -> "/* ... */"
            text.startsWith("import ") -> "import ..."
            text.startsWith("{") -> "{...}"
            else -> "..."
        }
    }

    override fun isCollapsedByDefault(node: ASTNode): Boolean {
        // Collapse imports by default, leave everything else expanded
        val text = node.text
        return text.startsWith("import ")
    }
}
