package com.darkmatter.rockit

/**
 * Scans Rockit source text for declarations to populate the Structure view.
 * Uses simple line-by-line pattern matching — no full parser needed.
 */
object RockitSymbolScanner {

    private val FUNCTION_PATTERN = Regex(
        """^(\s*)((?:suspend\s+)?(?:override\s+)?fun)\s+(\w+)\s*(?:<[^>]*>)?\s*\(([^)]*)\)(?:\s*:\s*(\S+))?"""
    )
    private val CLASS_PATTERN = Regex(
        """^(\s*)(data\s+class|sealed\s+class|class)\s+(\w+)"""
    )
    private val INTERFACE_PATTERN = Regex(
        """^(\s*)interface\s+(\w+)"""
    )
    private val ENUM_PATTERN = Regex(
        """^(\s*)enum\s+class\s+(\w+)"""
    )
    private val ACTOR_PATTERN = Regex(
        """^(\s*)actor\s+(\w+)"""
    )
    private val VIEW_PATTERN = Regex(
        """^(\s*)view\s+(\w+)"""
    )
    private val NAVIGATION_PATTERN = Regex(
        """^(\s*)navigation\s+(\w+)"""
    )
    private val THEME_PATTERN = Regex(
        """^(\s*)theme\s+(\w+)"""
    )
    private val OBJECT_PATTERN = Regex(
        """^(\s*)object\s+(\w+)"""
    )
    private val TYPE_ALIAS_PATTERN = Regex(
        """^(\s*)typealias\s+(\w+)\s*=\s*(.+)"""
    )
    private val PROPERTY_PATTERN = Regex(
        """^(\s*)(val|var)\s+(\w+)(?:\s*:\s*(\S+))?"""
    )

    fun scan(text: String): List<RockitSymbol> {
        val lines = text.lines()
        val topLevel = mutableListOf<RockitSymbol>()
        var currentContainer: RockitSymbol? = null
        var braceDepth = 0
        var containerStartDepth = 0
        var inString = false
        var inLineComment = false
        var inBlockComment = false

        for ((lineIndex, line) in lines.withIndex()) {
            // Track brace depth (rough — skip strings and comments)
            var i = 0
            inLineComment = false
            while (i < line.length) {
                val c = line[i]
                val next = if (i + 1 < line.length) line[i + 1] else '\u0000'

                if (inBlockComment) {
                    if (c == '*' && next == '/') {
                        inBlockComment = false
                        i += 2
                        continue
                    }
                    i++
                    continue
                }

                if (inString) {
                    if (c == '\\') { i += 2; continue }
                    if (c == '"') inString = false
                    i++
                    continue
                }

                when {
                    c == '/' && next == '/' -> { inLineComment = true; break }
                    c == '/' && next == '*' -> { inBlockComment = true; i += 2; continue }
                    c == '"' -> inString = true
                    c == '{' -> braceDepth++
                    c == '}' -> {
                        braceDepth--
                        if (currentContainer != null && braceDepth <= containerStartDepth) {
                            currentContainer = null
                        }
                    }
                }
                i++
            }

            if (inLineComment && !lineContainsCodeBefore(line)) continue

            // Skip lines inside block comments
            if (inBlockComment) continue

            // Try matching declarations
            val trimmed = line.trimStart()
            if (trimmed.startsWith("//") || trimmed.startsWith("/*")) continue

            val symbol = matchDeclaration(line, lineIndex)
            if (symbol != null) {
                val isTopLevel = braceDepth <= 1 && currentContainer == null
                val isContainer = symbol.kind in setOf(
                    SymbolKind.CLASS, SymbolKind.DATA_CLASS, SymbolKind.SEALED_CLASS,
                    SymbolKind.INTERFACE, SymbolKind.ENUM, SymbolKind.ACTOR,
                    SymbolKind.VIEW, SymbolKind.OBJECT
                )

                if (currentContainer != null && braceDepth > containerStartDepth) {
                    currentContainer.children.add(symbol)
                } else {
                    topLevel.add(symbol)
                    if (isContainer) {
                        currentContainer = symbol
                        containerStartDepth = braceDepth - if (line.contains("{")) 1 else 0
                    }
                }
            }
        }

        return topLevel
    }

    private fun matchDeclaration(line: String, lineIndex: Int): RockitSymbol? {
        ENUM_PATTERN.find(line)?.let { m ->
            return RockitSymbol(m.groupValues[2], SymbolKind.ENUM, null, lineIndex)
        }

        CLASS_PATTERN.find(line)?.let { m ->
            val keyword = m.groupValues[2].trim()
            val kind = when {
                keyword.startsWith("data") -> SymbolKind.DATA_CLASS
                keyword.startsWith("sealed") -> SymbolKind.SEALED_CLASS
                else -> SymbolKind.CLASS
            }
            val detail = when (kind) {
                SymbolKind.DATA_CLASS -> "data class"
                SymbolKind.SEALED_CLASS -> "sealed class"
                else -> "class"
            }
            return RockitSymbol(m.groupValues[3], kind, detail, lineIndex)
        }

        INTERFACE_PATTERN.find(line)?.let { m ->
            return RockitSymbol(m.groupValues[2], SymbolKind.INTERFACE, "interface", lineIndex)
        }

        ACTOR_PATTERN.find(line)?.let { m ->
            return RockitSymbol(m.groupValues[2], SymbolKind.ACTOR, "actor", lineIndex)
        }

        VIEW_PATTERN.find(line)?.let { m ->
            return RockitSymbol(m.groupValues[2], SymbolKind.VIEW, "view", lineIndex)
        }

        NAVIGATION_PATTERN.find(line)?.let { m ->
            return RockitSymbol(m.groupValues[2], SymbolKind.NAVIGATION, "navigation", lineIndex)
        }

        THEME_PATTERN.find(line)?.let { m ->
            return RockitSymbol(m.groupValues[2], SymbolKind.THEME, "theme", lineIndex)
        }

        OBJECT_PATTERN.find(line)?.let { m ->
            return RockitSymbol(m.groupValues[2], SymbolKind.OBJECT, "object", lineIndex)
        }

        TYPE_ALIAS_PATTERN.find(line)?.let { m ->
            return RockitSymbol(m.groupValues[2], SymbolKind.TYPE_ALIAS, "= ${m.groupValues[3].trim()}", lineIndex)
        }

        FUNCTION_PATTERN.find(line)?.let { m ->
            val name = m.groupValues[3]
            val params = m.groupValues[4].trim()
            val returnType = m.groupValues[5].takeIf { it.isNotEmpty() }
            val detail = buildString {
                append("(")
                append(params)
                append(")")
                if (returnType != null) {
                    append(": ")
                    append(returnType)
                }
            }
            return RockitSymbol(name, SymbolKind.FUNCTION, detail, lineIndex)
        }

        // Only match top-level properties (not inside function bodies)
        PROPERTY_PATTERN.find(line)?.let { m ->
            val indent = m.groupValues[1]
            // Only match if at class member level (4 spaces indent) or top level (0 indent)
            if (indent.length <= 4) {
                val keyword = m.groupValues[2]
                val name = m.groupValues[3]
                val type = m.groupValues[4].takeIf { it.isNotEmpty() }
                val detail = buildString {
                    append(keyword)
                    if (type != null) {
                        append(": ")
                        append(type)
                    }
                }
                return RockitSymbol(name, SymbolKind.PROPERTY, detail, lineIndex)
            }
        }

        return null
    }

    private fun lineContainsCodeBefore(line: String): Boolean {
        val commentStart = line.indexOf("//")
        if (commentStart <= 0) return false
        return line.substring(0, commentStart).isNotBlank()
    }
}
