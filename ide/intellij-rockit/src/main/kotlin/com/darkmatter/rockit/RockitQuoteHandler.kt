package com.darkmatter.rockit

import com.intellij.codeInsight.editorActions.SimpleTokenSetQuoteHandler

class RockitQuoteHandler : SimpleTokenSetQuoteHandler(
    RockitTokenTypes.STRING_LITERAL,
    RockitTokenTypes.MULTILINE_STRING_LITERAL
)
