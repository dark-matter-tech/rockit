package com.darkmatter.rockit

import com.intellij.execution.configurations.GeneralCommandLine
import com.intellij.openapi.project.Project
import com.intellij.openapi.vfs.VirtualFile
import com.intellij.platform.lsp.api.ProjectWideLspServerDescriptor

internal class RockitLspServerDescriptor(project: Project) :
    ProjectWideLspServerDescriptor(project, "Rockit") {

    override fun isSupportedFile(file: VirtualFile): Boolean {
        return file.extension == "rok" || file.extension == "rokb"
    }

    override fun createCommandLine(): GeneralCommandLine {
        return GeneralCommandLine("rockit", "lsp")
            .withParentEnvironmentType(GeneralCommandLine.ParentEnvironmentType.CONSOLE)
    }
}
