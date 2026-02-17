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
}
