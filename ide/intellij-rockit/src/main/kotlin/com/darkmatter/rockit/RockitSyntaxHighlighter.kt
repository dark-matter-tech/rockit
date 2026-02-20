package com.darkmatter.rockit

import com.intellij.openapi.editor.DefaultLanguageHighlighterColors
import com.intellij.openapi.editor.HighlighterColors
import com.intellij.openapi.editor.colors.TextAttributesKey
import com.intellij.openapi.editor.colors.TextAttributesKey.createTextAttributesKey
import com.intellij.openapi.editor.markup.EffectType
import com.intellij.openapi.editor.markup.TextAttributes
import com.intellij.openapi.fileTypes.SyntaxHighlighterBase
import com.intellij.psi.tree.IElementType
import com.intellij.ui.JBColor
import java.awt.Color
import java.awt.Font

class RockitSyntaxHighlighter : SyntaxHighlighterBase() {

    companion object {
        // --- Xcode/Swift-inspired color palette ---
        // JBColor(lightThemeColor, darkThemeColor)

        private fun attrs(fg: JBColor, fontType: Int = Font.PLAIN): TextAttributes {
            return TextAttributes(fg, null, null, null, fontType)
        }

        // Declaration keywords: fun, val, var, class, etc. — bold
        @JvmField
        @Suppress("DEPRECATION")
        val KEYWORD = createTextAttributesKey(
            "ROCKIT_KEYWORD",
            attrs(JBColor(Color(0x00, 0x33, 0xB3), Color(0xFF, 0x7A, 0xB2)), Font.BOLD)
        )

        // Control flow: if, else, for, while, return — bold
        @JvmField
        @Suppress("DEPRECATION")
        val CONTROL_KEYWORD = createTextAttributesKey(
            "ROCKIT_CONTROL_KEYWORD",
            attrs(JBColor(Color(0x00, 0x33, 0xB3), Color(0xFF, 0x7A, 0xB2)), Font.BOLD)
        )

        // Rockit-specific: view, actor, suspend, concurrent — purple, bold
        @JvmField
        @Suppress("DEPRECATION")
        val ROCKIT_KEYWORD = createTextAttributesKey(
            "ROCKIT_BUILTIN_KEYWORD",
            attrs(JBColor(Color(0x87, 0x10, 0x94), Color(0xB3, 0x81, 0xCF)), Font.BOLD)
        )

        // Boolean literals: true, false — bright orange, bold
        @JvmField
        @Suppress("DEPRECATION")
        val BOOLEAN_LITERAL = createTextAttributesKey(
            "ROCKIT_BOOLEAN_LITERAL",
            attrs(JBColor(Color(0xE5, 0x7C, 0x00), Color(0xFF, 0xA0, 0x30)), Font.BOLD)
        )

        // Null literal — red/coral, bold
        @JvmField
        @Suppress("DEPRECATION")
        val NULL_LITERAL = createTextAttributesKey(
            "ROCKIT_NULL_LITERAL",
            attrs(JBColor(Color(0xC6, 0x28, 0x28), Color(0xFF, 0x6B, 0x68)), Font.BOLD)
        )

        // Optional operators: ?, ?., ?: — cyan, bold
        @JvmField
        @Suppress("DEPRECATION")
        val OPTIONAL_OPERATOR = createTextAttributesKey(
            "ROCKIT_OPTIONAL_OPERATOR",
            attrs(JBColor(Color(0x00, 0x83, 0x8F), Color(0x56, 0xB6, 0xC2)), Font.BOLD)
        )

        // Force unwrap: !! — red/warning, bold
        @JvmField
        @Suppress("DEPRECATION")
        val FORCE_UNWRAP = createTextAttributesKey(
            "ROCKIT_FORCE_UNWRAP",
            attrs(JBColor(Color(0xC6, 0x28, 0x28), Color(0xFF, 0x6B, 0x68)), Font.BOLD)
        )

        // Boolean-prefixed identifiers: isActive, hasAccess, etc. — same as boolean literal
        @JvmField
        val BOOLEAN_IDENTIFIER = createTextAttributesKey(
            "ROCKIT_BOOLEAN_IDENTIFIER",
            BOOLEAN_LITERAL
        )

        // Optional identifiers: val name: String? — softer cyan to associate with ? operator
        @JvmField
        @Suppress("DEPRECATION")
        val OPTIONAL_IDENTIFIER = createTextAttributesKey(
            "ROCKIT_OPTIONAL_IDENTIFIER",
            attrs(JBColor(Color(0x00, 0x6B, 0x75), Color(0x6B, 0xC9, 0xD4)))
        )

        // Function calls: identifier followed by ( — yellow
        @JvmField
        @Suppress("DEPRECATION")
        val FUNCTION_CALL = createTextAttributesKey(
            "ROCKIT_FUNCTION_CALL",
            attrs(JBColor(Color(0x7A, 0x5E, 0x2D), Color(0xDC, 0xDC, 0xAA)))
        )

        // Built-in types: String, Int, Bool, etc. — teal
        @JvmField
        @Suppress("DEPRECATION")
        val BUILTIN_TYPE = createTextAttributesKey(
            "ROCKIT_BUILTIN_TYPE",
            attrs(JBColor(Color(0x00, 0x62, 0x7A), Color(0x5D, 0xD8, 0xB4)))
        )

        // Built-in functions: println, listOf, etc. — teal, italic
        @JvmField
        @Suppress("DEPRECATION")
        val BUILTIN_FUNCTION = createTextAttributesKey(
            "ROCKIT_BUILTIN_FUNCTION",
            attrs(JBColor(Color(0x00, 0x62, 0x7A), Color(0x67, 0xB7, 0xA4)), Font.ITALIC)
        )

        // Strings — red/salmon (dark), green (light)
        @JvmField
        @Suppress("DEPRECATION")
        val STRING = createTextAttributesKey(
            "ROCKIT_STRING",
            attrs(JBColor(Color(0x06, 0x7D, 0x17), Color(0xFC, 0x6A, 0x5D)))
        )

        // Escape sequences — bold
        @JvmField
        @Suppress("DEPRECATION")
        val STRING_ESCAPE = createTextAttributesKey(
            "ROCKIT_STRING_ESCAPE",
            attrs(JBColor(Color(0x00, 0x37, 0xA6), Color(0xE9, 0xB9, 0x6E)), Font.BOLD)
        )

        // String interpolation ($name, ${expr}) — bold, distinct from string
        @JvmField
        @Suppress("DEPRECATION")
        val STRING_INTERPOLATION = createTextAttributesKey(
            "ROCKIT_STRING_INTERPOLATION",
            attrs(JBColor(Color(0x00, 0x37, 0xA6), Color(0x41, 0xA1, 0xC0)), Font.BOLD)
        )

        // Numbers — yellow/gold (dark), blue (light)
        @JvmField
        @Suppress("DEPRECATION")
        val NUMBER = createTextAttributesKey(
            "ROCKIT_NUMBER",
            attrs(JBColor(Color(0x17, 0x50, 0xEB), Color(0xD0, 0xBF, 0x69)))
        )

        // Line comments — italic
        @JvmField
        @Suppress("DEPRECATION")
        val LINE_COMMENT = createTextAttributesKey(
            "ROCKIT_LINE_COMMENT",
            attrs(JBColor(Color(0x8C, 0x8C, 0x8C), Color(0x7F, 0x8C, 0x98)), Font.ITALIC)
        )

        // Block comments — italic
        @JvmField
        @Suppress("DEPRECATION")
        val BLOCK_COMMENT = createTextAttributesKey(
            "ROCKIT_BLOCK_COMMENT",
            attrs(JBColor(Color(0x8C, 0x8C, 0x8C), Color(0x7F, 0x8C, 0x98)), Font.ITALIC)
        )

        // Operators
        @JvmField
        val OPERATOR = createTextAttributesKey(
            "ROCKIT_OPERATOR",
            DefaultLanguageHighlighterColors.OPERATION_SIGN
        )

        // Parentheses
        @JvmField
        val PARENTHESES = createTextAttributesKey(
            "ROCKIT_PARENTHESES",
            DefaultLanguageHighlighterColors.PARENTHESES
        )

        // Braces
        @JvmField
        val BRACES = createTextAttributesKey(
            "ROCKIT_BRACES",
            DefaultLanguageHighlighterColors.BRACES
        )

        // Brackets
        @JvmField
        val BRACKETS = createTextAttributesKey(
            "ROCKIT_BRACKETS",
            DefaultLanguageHighlighterColors.BRACKETS
        )

        // Dot, comma, semicolon — keep theme defaults
        @JvmField
        val DOT = createTextAttributesKey(
            "ROCKIT_DOT",
            DefaultLanguageHighlighterColors.DOT
        )

        @JvmField
        val COMMA = createTextAttributesKey(
            "ROCKIT_COMMA",
            DefaultLanguageHighlighterColors.COMMA
        )

        @JvmField
        val SEMICOLON = createTextAttributesKey(
            "ROCKIT_SEMICOLON",
            DefaultLanguageHighlighterColors.SEMICOLON
        )

        // Annotation — orange
        @JvmField
        @Suppress("DEPRECATION")
        val ANNOTATION = createTextAttributesKey(
            "ROCKIT_ANNOTATION",
            attrs(JBColor(Color(0xBB, 0xB5, 0x29), Color(0xFF, 0xA1, 0x4F)))
        )

        // Identifier / local variable — light blue (dark), dark blue (light)
        @JvmField
        @Suppress("DEPRECATION")
        val IDENTIFIER = createTextAttributesKey(
            "ROCKIT_IDENTIFIER",
            attrs(JBColor(Color(0x00, 0x10, 0x80), Color(0x9C, 0xDC, 0xFE)))
        )

        // Bad character
        @JvmField
        val BAD_CHAR = createTextAttributesKey(
            "ROCKIT_BAD_CHARACTER",
            HighlighterColors.BAD_CHARACTER
        )

        private val KEYWORD_KEYS = arrayOf(KEYWORD)
        private val CONTROL_KEYWORD_KEYS = arrayOf(CONTROL_KEYWORD)
        private val ROCKIT_KEYWORD_KEYS = arrayOf(ROCKIT_KEYWORD)
        private val BOOLEAN_LITERAL_KEYS = arrayOf(BOOLEAN_LITERAL)
        private val NULL_LITERAL_KEYS = arrayOf(NULL_LITERAL)
        private val OPTIONAL_OPERATOR_KEYS = arrayOf(OPTIONAL_OPERATOR)
        private val FORCE_UNWRAP_KEYS = arrayOf(FORCE_UNWRAP)
        private val BOOLEAN_IDENTIFIER_KEYS = arrayOf(BOOLEAN_IDENTIFIER)
        private val OPTIONAL_IDENTIFIER_KEYS = arrayOf(OPTIONAL_IDENTIFIER)
        private val FUNCTION_CALL_KEYS = arrayOf(FUNCTION_CALL)
        private val BUILTIN_TYPE_KEYS = arrayOf(BUILTIN_TYPE)
        private val BUILTIN_FUNCTION_KEYS = arrayOf(BUILTIN_FUNCTION)
        private val STRING_KEYS = arrayOf(STRING)
        private val STRING_ESCAPE_KEYS = arrayOf(STRING_ESCAPE)
        private val STRING_INTERPOLATION_KEYS = arrayOf(STRING_INTERPOLATION)
        private val NUMBER_KEYS = arrayOf(NUMBER)
        private val LINE_COMMENT_KEYS = arrayOf(LINE_COMMENT)
        private val BLOCK_COMMENT_KEYS = arrayOf(BLOCK_COMMENT)
        private val OPERATOR_KEYS = arrayOf(OPERATOR)
        private val PARENTHESES_KEYS = arrayOf(PARENTHESES)
        private val BRACES_KEYS = arrayOf(BRACES)
        private val BRACKETS_KEYS = arrayOf(BRACKETS)
        private val DOT_KEYS = arrayOf(DOT)
        private val COMMA_KEYS = arrayOf(COMMA)
        private val SEMICOLON_KEYS = arrayOf(SEMICOLON)
        private val ANNOTATION_KEYS = arrayOf(ANNOTATION)
        private val IDENTIFIER_KEYS = arrayOf(IDENTIFIER)
        private val BAD_CHAR_KEYS = arrayOf(BAD_CHAR)
        private val EMPTY_KEYS = emptyArray<TextAttributesKey>()
    }

    override fun getHighlightingLexer() = RockitLexerAdapter()

    override fun getTokenHighlights(tokenType: IElementType): Array<TextAttributesKey> {
        return when (tokenType) {
            // Declaration keywords
            RockitTokenTypes.KW_FUN, RockitTokenTypes.KW_VAL, RockitTokenTypes.KW_VAR,
            RockitTokenTypes.KW_CLASS, RockitTokenTypes.KW_INTERFACE, RockitTokenTypes.KW_OBJECT,
            RockitTokenTypes.KW_ENUM, RockitTokenTypes.KW_DATA, RockitTokenTypes.KW_SEALED,
            RockitTokenTypes.KW_ABSTRACT, RockitTokenTypes.KW_OPEN, RockitTokenTypes.KW_OVERRIDE,
            RockitTokenTypes.KW_PRIVATE, RockitTokenTypes.KW_INTERNAL, RockitTokenTypes.KW_PUBLIC,
            RockitTokenTypes.KW_PROTECTED, RockitTokenTypes.KW_COMPANION,
            RockitTokenTypes.KW_TYPEALIAS, RockitTokenTypes.KW_VARARG,
            RockitTokenTypes.KW_IMPORT, RockitTokenTypes.KW_PACKAGE,
            RockitTokenTypes.KW_THIS, RockitTokenTypes.KW_SUPER,
            RockitTokenTypes.KW_CONSTRUCTOR, RockitTokenTypes.KW_INIT,
            RockitTokenTypes.KW_WHERE, RockitTokenTypes.KW_OUT
            -> KEYWORD_KEYS

            // Control flow keywords
            RockitTokenTypes.KW_IF, RockitTokenTypes.KW_ELSE, RockitTokenTypes.KW_WHEN,
            RockitTokenTypes.KW_FOR, RockitTokenTypes.KW_WHILE, RockitTokenTypes.KW_DO,
            RockitTokenTypes.KW_RETURN, RockitTokenTypes.KW_BREAK, RockitTokenTypes.KW_CONTINUE,
            RockitTokenTypes.KW_IN, RockitTokenTypes.KW_IS, RockitTokenTypes.KW_AS,
            RockitTokenTypes.KW_THROW, RockitTokenTypes.KW_TRY,
            RockitTokenTypes.KW_CATCH, RockitTokenTypes.KW_FINALLY
            -> CONTROL_KEYWORD_KEYS

            // Rockit-specific keywords (purple)
            RockitTokenTypes.KW_VIEW, RockitTokenTypes.KW_ACTOR,
            RockitTokenTypes.KW_NAVIGATION, RockitTokenTypes.KW_ROUTE,
            RockitTokenTypes.KW_THEME, RockitTokenTypes.KW_STYLE,
            RockitTokenTypes.KW_SUSPEND, RockitTokenTypes.KW_ASYNC,
            RockitTokenTypes.KW_AWAIT, RockitTokenTypes.KW_CONCURRENT,
            RockitTokenTypes.KW_WEAK, RockitTokenTypes.KW_UNOWNED
            -> ROCKIT_KEYWORD_KEYS

            // Boolean literals
            RockitTokenTypes.KW_TRUE, RockitTokenTypes.KW_FALSE
            -> BOOLEAN_LITERAL_KEYS

            // Null literal
            RockitTokenTypes.KW_NULL -> NULL_LITERAL_KEYS

            // Boolean-prefixed identifiers
            RockitTokenTypes.BOOLEAN_IDENTIFIER -> BOOLEAN_IDENTIFIER_KEYS

            // Optional identifiers (val name: String?)
            RockitTokenTypes.OPTIONAL_IDENTIFIER -> OPTIONAL_IDENTIFIER_KEYS

            // Function calls
            RockitTokenTypes.FUNCTION_CALL -> FUNCTION_CALL_KEYS

            // Built-in types
            RockitTokenTypes.BUILTIN_TYPE -> BUILTIN_TYPE_KEYS

            // Built-in functions
            RockitTokenTypes.BUILTIN_FUNCTION -> BUILTIN_FUNCTION_KEYS

            // Strings
            RockitTokenTypes.STRING_LITERAL, RockitTokenTypes.MULTILINE_STRING_LITERAL
            -> STRING_KEYS

            RockitTokenTypes.STRING_ESCAPE -> STRING_ESCAPE_KEYS
            RockitTokenTypes.STRING_INTERPOLATION -> STRING_INTERPOLATION_KEYS

            // Numbers
            RockitTokenTypes.INTEGER_LITERAL, RockitTokenTypes.FLOAT_LITERAL
            -> NUMBER_KEYS

            // Comments
            RockitTokenTypes.LINE_COMMENT -> LINE_COMMENT_KEYS
            RockitTokenTypes.BLOCK_COMMENT -> BLOCK_COMMENT_KEYS

            // Optional operators — cyan
            RockitTokenTypes.QUESTION, RockitTokenTypes.QUESTION_DOT,
            RockitTokenTypes.ELVIS
            -> OPTIONAL_OPERATOR_KEYS

            // Force unwrap — red/warning
            RockitTokenTypes.BANG_BANG -> FORCE_UNWRAP_KEYS

            // Operators
            RockitTokenTypes.PLUS, RockitTokenTypes.MINUS, RockitTokenTypes.STAR,
            RockitTokenTypes.SLASH, RockitTokenTypes.PERCENT,
            RockitTokenTypes.EQ_EQ, RockitTokenTypes.BANG_EQ,
            RockitTokenTypes.LT, RockitTokenTypes.LT_EQ,
            RockitTokenTypes.GT, RockitTokenTypes.GT_EQ,
            RockitTokenTypes.AMP_AMP, RockitTokenTypes.PIPE_PIPE, RockitTokenTypes.BANG,
            RockitTokenTypes.EQ, RockitTokenTypes.PLUS_EQ, RockitTokenTypes.MINUS_EQ,
            RockitTokenTypes.STAR_EQ, RockitTokenTypes.SLASH_EQ, RockitTokenTypes.PERCENT_EQ,
            RockitTokenTypes.DOT_DOT, RockitTokenTypes.DOT_DOT_LESS,
            RockitTokenTypes.ARROW, RockitTokenTypes.FAT_ARROW, RockitTokenTypes.COLON_COLON
            -> OPERATOR_KEYS

            // Delimiters
            RockitTokenTypes.LPAREN, RockitTokenTypes.RPAREN -> PARENTHESES_KEYS
            RockitTokenTypes.LBRACE, RockitTokenTypes.RBRACE -> BRACES_KEYS
            RockitTokenTypes.LBRACKET, RockitTokenTypes.RBRACKET -> BRACKETS_KEYS
            RockitTokenTypes.DOT -> DOT_KEYS
            RockitTokenTypes.COMMA -> COMMA_KEYS
            RockitTokenTypes.COLON -> SEMICOLON_KEYS
            RockitTokenTypes.SEMICOLON -> SEMICOLON_KEYS

            // Annotations
            RockitTokenTypes.ANNOTATION -> ANNOTATION_KEYS

            // Identifiers
            RockitTokenTypes.IDENTIFIER -> IDENTIFIER_KEYS

            // Bad character
            com.intellij.psi.TokenType.BAD_CHARACTER -> BAD_CHAR_KEYS

            else -> EMPTY_KEYS
        }
    }
}
