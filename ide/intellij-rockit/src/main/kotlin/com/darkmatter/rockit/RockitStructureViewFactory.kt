package com.darkmatter.rockit

import com.intellij.ide.structureView.StructureViewBuilder
import com.intellij.ide.structureView.StructureViewModel
import com.intellij.ide.structureView.TreeBasedStructureViewBuilder
import com.intellij.lang.PsiStructureViewFactory
import com.intellij.openapi.editor.Editor
import com.intellij.psi.PsiFile

class RockitStructureViewFactory : PsiStructureViewFactory {
    override fun getStructureViewBuilder(psiFile: PsiFile): StructureViewBuilder? {
        val ext = psiFile.virtualFile?.extension
        if (ext != "rok" && ext != "rokb") return null
        return RockitStructureViewBuilder(psiFile)
    }
}

class RockitStructureViewBuilder(private val psiFile: PsiFile) : TreeBasedStructureViewBuilder() {
    override fun createStructureViewModel(editor: Editor?): StructureViewModel {
        return RockitStructureViewModel(psiFile, editor)
    }
}
