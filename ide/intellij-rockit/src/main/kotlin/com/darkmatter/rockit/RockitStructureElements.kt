package com.darkmatter.rockit

import com.intellij.icons.AllIcons
import com.intellij.ide.structureView.StructureViewTreeElement
import com.intellij.ide.structureView.impl.common.PsiTreeElementBase
import com.intellij.ide.util.treeView.smartTree.SortableTreeElement
import com.intellij.ide.util.treeView.smartTree.TreeElement
import com.intellij.navigation.ItemPresentation
import com.intellij.openapi.editor.ScrollType
import com.intellij.openapi.fileEditor.FileEditorManager
import com.intellij.psi.PsiFile
import javax.swing.Icon

/**
 * A symbol found by scanning the .rok file text.
 */
data class RockitSymbol(
    val name: String,
    val kind: SymbolKind,
    val detail: String?,
    val line: Int,
    val children: MutableList<RockitSymbol> = mutableListOf()
)

enum class SymbolKind {
    FUNCTION, CLASS, DATA_CLASS, SEALED_CLASS, INTERFACE, ENUM,
    ACTOR, VIEW, NAVIGATION, THEME, OBJECT, PROPERTY, TYPE_ALIAS
}

/**
 * Root element — represents the file, children are top-level declarations.
 */
class RockitFileStructureElement(psiFile: PsiFile) : PsiTreeElementBase<PsiFile>(psiFile) {

    override fun getPresentableText(): String? = element?.name

    override fun getChildrenBase(): Collection<StructureViewTreeElement> {
        val file = element ?: return emptyList()
        val text = file.text ?: return emptyList()
        val symbols = RockitSymbolScanner.scan(text)
        return symbols.map { RockitSymbolElement(it, file) }
    }
}

/**
 * A single symbol in the structure tree.
 */
class RockitSymbolElement(
    private val symbol: RockitSymbol,
    private val psiFile: PsiFile
) : StructureViewTreeElement, SortableTreeElement {

    override fun getValue(): Any = symbol

    override fun getAlphaSortKey(): String = symbol.name

    fun hasChildren(): Boolean = symbol.children.isNotEmpty()

    override fun getPresentation(): ItemPresentation = object : ItemPresentation {
        override fun getPresentableText(): String = symbol.name
        override fun getLocationString(): String? = symbol.detail
        override fun getIcon(unused: Boolean): Icon? = when (symbol.kind) {
            SymbolKind.FUNCTION -> AllIcons.Nodes.Function
            SymbolKind.CLASS -> AllIcons.Nodes.Class
            SymbolKind.DATA_CLASS -> AllIcons.Nodes.Class
            SymbolKind.SEALED_CLASS -> AllIcons.Nodes.Class
            SymbolKind.INTERFACE -> AllIcons.Nodes.Interface
            SymbolKind.ENUM -> AllIcons.Nodes.Enum
            SymbolKind.ACTOR -> AllIcons.Nodes.Class
            SymbolKind.VIEW -> AllIcons.Nodes.Class
            SymbolKind.NAVIGATION -> AllIcons.Nodes.Module
            SymbolKind.THEME -> AllIcons.Nodes.Module
            SymbolKind.OBJECT -> AllIcons.Nodes.AnonymousClass
            SymbolKind.PROPERTY -> AllIcons.Nodes.Property
            SymbolKind.TYPE_ALIAS -> AllIcons.Nodes.Type
        }
    }

    override fun getChildren(): Array<TreeElement> {
        return symbol.children.map { RockitSymbolElement(it, psiFile) }.toTypedArray()
    }

    override fun navigate(requestFocus: Boolean) {
        val editor = FileEditorManager.getInstance(psiFile.project).selectedTextEditor ?: return
        val document = editor.document
        if (symbol.line < document.lineCount) {
            val offset = document.getLineStartOffset(symbol.line)
            editor.caretModel.moveToOffset(offset)
            editor.scrollingModel.scrollToCaret(ScrollType.CENTER)
            if (requestFocus) {
                val component = editor.contentComponent
                component.requestFocusInWindow()
            }
        }
    }

    override fun canNavigate(): Boolean = true
    override fun canNavigateToSource(): Boolean = true
}
