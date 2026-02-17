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
            for (p in BOOL_PREFIXES) {
                if (text.length > p.length && text.startsWith(p) && text[p.length].isUpperCase()) {
                    return RockitTokenTypes.BOOLEAN_IDENTIFIER
                }
            }
        }
        return type
    }
}
