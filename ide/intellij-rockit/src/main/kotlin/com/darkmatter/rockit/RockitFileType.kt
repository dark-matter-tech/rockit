package com.darkmatter.rockit

import com.intellij.openapi.fileTypes.LanguageFileType
import javax.swing.Icon

class RockitFileType private constructor() : LanguageFileType(RockitLanguage.INSTANCE) {
    companion object {
        @JvmStatic
        val INSTANCE = RockitFileType()
    }

    override fun getName(): String = "Rockit"
    override fun getDescription(): String = "Rockit language file"
    override fun getDefaultExtension(): String = "rok"
    override fun getIcon(): Icon = RockitIcons.FILE
}
