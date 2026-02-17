package com.darkmatter.rockit

import com.intellij.lang.BracePair
import com.intellij.lang.PairedBraceMatcher
import com.intellij.psi.PsiFile
import com.intellij.psi.tree.IElementType

class RockitBraceMatcher : PairedBraceMatcher {

    companion object {
        private val PAIRS = arrayOf(
            BracePair(RockitTokenTypes.LPAREN, RockitTokenTypes.RPAREN, false),
            BracePair(RockitTokenTypes.LBRACE, RockitTokenTypes.RBRACE, true),
            BracePair(RockitTokenTypes.LBRACKET, RockitTokenTypes.RBRACKET, false),
        )
    }

    override fun getPairs(): Array<BracePair> = PAIRS

    override fun isPairedBracesAllowedBeforeType(
        lbraceType: IElementType,
        contextType: IElementType?
    ): Boolean = true

    override fun getCodeConstructStart(file: PsiFile, openingBraceOffset: Int): Int =
        openingBraceOffset
}
