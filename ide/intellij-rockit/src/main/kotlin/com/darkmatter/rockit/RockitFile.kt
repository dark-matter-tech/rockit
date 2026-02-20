package com.darkmatter.rockit

import com.intellij.extapi.psi.PsiFileBase
import com.intellij.openapi.fileTypes.FileType
import com.intellij.psi.FileViewProvider

class RockitFile(viewProvider: FileViewProvider) : PsiFileBase(viewProvider, RockitLanguage.INSTANCE) {
    override fun getFileType(): FileType = RockitFileType.INSTANCE
}
