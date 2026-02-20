package com.darkmatter.rockit

import com.intellij.ide.structureView.StructureViewModel
import com.intellij.ide.structureView.StructureViewModelBase
import com.intellij.ide.structureView.StructureViewTreeElement
import com.intellij.openapi.editor.Editor
import com.intellij.psi.PsiFile

class RockitStructureViewModel(psiFile: PsiFile, editor: Editor?) :
    StructureViewModelBase(psiFile, editor, RockitFileStructureElement(psiFile)),
    StructureViewModel.ElementInfoProvider {

    override fun isAlwaysShowsPlus(element: StructureViewTreeElement?): Boolean = false
    override fun isAlwaysLeaf(element: StructureViewTreeElement?): Boolean {
        return element is RockitSymbolElement && !element.hasChildren()
    }
}
