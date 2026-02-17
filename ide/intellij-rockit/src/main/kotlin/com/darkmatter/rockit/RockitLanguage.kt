package com.darkmatter.rockit

import com.intellij.lang.Language

class RockitLanguage private constructor() : Language("Rockit") {
    companion object {
        @JvmStatic
        val INSTANCE = RockitLanguage()
    }
}
