package com.darkmatter.rockit

import com.intellij.lexer.FlexAdapter
import com.intellij.psi.tree.IElementType

class RockitLexerAdapter : FlexAdapter(RockitLexer(null)) {

    companion object {
        private val BOOL_PREFIXES = arrayOf("is", "has", "can", "should", "was", "will", "did", "does")
    }

    override fun getTokenType(): IElementType? {
        val type = super.getTokenType() ?: return null
        if (type === RockitTokenTypes.IDENTIFIER) {
            val text = bufferSequence.subSequence(tokenStart, tokenEnd)

            // Boolean-prefixed identifiers: isActive, hasAccess, canEdit, etc.
            for (p in BOOL_PREFIXES) {
                if (text.length > p.length && text.startsWith(p) && text[p.length].isUpperCase()) {
                    return RockitTokenTypes.BOOLEAN_IDENTIFIER
                }
            }

            // Optional identifiers: val name: String? or fun f(name: String?)
            if (isOptionalDecl()) {
                return RockitTokenTypes.OPTIONAL_IDENTIFIER
            }

            // Function calls: identifier followed by (
            val buf = bufferSequence
            val end = tokenEnd
            val bufEnd = bufferEnd
            var i = end
            while (i < bufEnd && (buf[i] == ' ' || buf[i] == '\t')) {
                i++
            }
            if (i < bufEnd && buf[i] == '(') {
                return RockitTokenTypes.FUNCTION_CALL
            }
        }
        return type
    }

    /**
     * Scan ahead from the current IDENTIFIER token to detect `identifier : Type?`
     * or `identifier : Type<...>?` patterns — marks the identifier as optional.
     */
    private fun isOptionalDecl(): Boolean {
        val buf = bufferSequence
        val bufLen = bufferEnd
        var i = tokenEnd

        // Skip whitespace
        while (i < bufLen && (buf[i] == ' ' || buf[i] == '\t')) i++

        // Must see ':'
        if (i >= bufLen || buf[i] != ':') return false
        i++

        // Skip whitespace after ':'
        while (i < bufLen && (buf[i] == ' ' || buf[i] == '\t')) i++

        // Read the type name (letters, digits, underscores, dots for qualified types)
        val typeStart = i
        while (i < bufLen && (buf[i].isLetterOrDigit() || buf[i] == '_' || buf[i] == '.')) i++
        if (i == typeStart) return false  // no type name found

        // Skip optional generic parameters: <...> (with nesting)
        if (i < bufLen && buf[i] == '<') {
            var depth = 1
            i++
            while (i < bufLen && depth > 0) {
                when (buf[i]) {
                    '<' -> depth++
                    '>' -> depth--
                }
                i++
            }
        }

        // The next character must be '?' for this to be an optional type
        return i < bufLen && buf[i] == '?'
    }
}
