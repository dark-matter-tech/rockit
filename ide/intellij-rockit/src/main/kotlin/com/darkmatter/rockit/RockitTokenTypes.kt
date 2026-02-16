package com.darkmatter.rockit

import com.intellij.psi.tree.IElementType
import com.intellij.psi.tree.TokenSet

class RockitTokenType(debugName: String) : IElementType(debugName, RockitLanguage.INSTANCE)

object RockitTokenTypes {
    // --- Keywords ---
    @JvmField val KW_FUN = RockitTokenType("fun")
    @JvmField val KW_VAL = RockitTokenType("val")
    @JvmField val KW_VAR = RockitTokenType("var")
    @JvmField val KW_CLASS = RockitTokenType("class")
    @JvmField val KW_INTERFACE = RockitTokenType("interface")
    @JvmField val KW_OBJECT = RockitTokenType("object")
    @JvmField val KW_ENUM = RockitTokenType("enum")
    @JvmField val KW_DATA = RockitTokenType("data")
    @JvmField val KW_SEALED = RockitTokenType("sealed")
    @JvmField val KW_ABSTRACT = RockitTokenType("abstract")
    @JvmField val KW_OPEN = RockitTokenType("open")
    @JvmField val KW_OVERRIDE = RockitTokenType("override")
    @JvmField val KW_PRIVATE = RockitTokenType("private")
    @JvmField val KW_INTERNAL = RockitTokenType("internal")
    @JvmField val KW_PUBLIC = RockitTokenType("public")
    @JvmField val KW_PROTECTED = RockitTokenType("protected")
    @JvmField val KW_COMPANION = RockitTokenType("companion")
    @JvmField val KW_TYPEALIAS = RockitTokenType("typealias")
    @JvmField val KW_VARARG = RockitTokenType("vararg")
    @JvmField val KW_IMPORT = RockitTokenType("import")
    @JvmField val KW_PACKAGE = RockitTokenType("package")
    @JvmField val KW_THIS = RockitTokenType("this")
    @JvmField val KW_SUPER = RockitTokenType("super")
    @JvmField val KW_CONSTRUCTOR = RockitTokenType("constructor")
    @JvmField val KW_INIT = RockitTokenType("init")
    @JvmField val KW_WHERE = RockitTokenType("where")
    @JvmField val KW_OUT = RockitTokenType("out")

    // Control flow
    @JvmField val KW_IF = RockitTokenType("if")
    @JvmField val KW_ELSE = RockitTokenType("else")
    @JvmField val KW_WHEN = RockitTokenType("when")
    @JvmField val KW_FOR = RockitTokenType("for")
    @JvmField val KW_WHILE = RockitTokenType("while")
    @JvmField val KW_DO = RockitTokenType("do")
    @JvmField val KW_RETURN = RockitTokenType("return")
    @JvmField val KW_BREAK = RockitTokenType("break")
    @JvmField val KW_CONTINUE = RockitTokenType("continue")
    @JvmField val KW_IN = RockitTokenType("in")
    @JvmField val KW_IS = RockitTokenType("is")
    @JvmField val KW_AS = RockitTokenType("as")
    @JvmField val KW_THROW = RockitTokenType("throw")
    @JvmField val KW_TRY = RockitTokenType("try")
    @JvmField val KW_CATCH = RockitTokenType("catch")
    @JvmField val KW_FINALLY = RockitTokenType("finally")

    // Rockit-specific
    @JvmField val KW_VIEW = RockitTokenType("view")
    @JvmField val KW_ACTOR = RockitTokenType("actor")
    @JvmField val KW_NAVIGATION = RockitTokenType("navigation")
    @JvmField val KW_ROUTE = RockitTokenType("route")
    @JvmField val KW_THEME = RockitTokenType("theme")
    @JvmField val KW_STYLE = RockitTokenType("style")
    @JvmField val KW_SUSPEND = RockitTokenType("suspend")
    @JvmField val KW_ASYNC = RockitTokenType("async")
    @JvmField val KW_AWAIT = RockitTokenType("await")
    @JvmField val KW_CONCURRENT = RockitTokenType("concurrent")
    @JvmField val KW_WEAK = RockitTokenType("weak")
    @JvmField val KW_UNOWNED = RockitTokenType("unowned")

    // Literals
    @JvmField val KW_TRUE = RockitTokenType("true")
    @JvmField val KW_FALSE = RockitTokenType("false")
    @JvmField val KW_NULL = RockitTokenType("null")

    // --- Operators ---
    @JvmField val PLUS = RockitTokenType("+")
    @JvmField val MINUS = RockitTokenType("-")
    @JvmField val STAR = RockitTokenType("*")
    @JvmField val SLASH = RockitTokenType("/")
    @JvmField val PERCENT = RockitTokenType("%")
    @JvmField val EQ_EQ = RockitTokenType("==")
    @JvmField val BANG_EQ = RockitTokenType("!=")
    @JvmField val LT = RockitTokenType("<")
    @JvmField val LT_EQ = RockitTokenType("<=")
    @JvmField val GT = RockitTokenType(">")
    @JvmField val GT_EQ = RockitTokenType(">=")
    @JvmField val AMP_AMP = RockitTokenType("&&")
    @JvmField val PIPE_PIPE = RockitTokenType("||")
    @JvmField val BANG = RockitTokenType("!")
    @JvmField val EQ = RockitTokenType("=")
    @JvmField val PLUS_EQ = RockitTokenType("+=")
    @JvmField val MINUS_EQ = RockitTokenType("-=")
    @JvmField val STAR_EQ = RockitTokenType("*=")
    @JvmField val SLASH_EQ = RockitTokenType("/=")
    @JvmField val PERCENT_EQ = RockitTokenType("%=")
    @JvmField val QUESTION = RockitTokenType("?")
    @JvmField val QUESTION_DOT = RockitTokenType("?.")
    @JvmField val ELVIS = RockitTokenType("?:")
    @JvmField val BANG_BANG = RockitTokenType("!!")
    @JvmField val DOT_DOT = RockitTokenType("..")
    @JvmField val DOT_DOT_LESS = RockitTokenType("..<")
    @JvmField val ARROW = RockitTokenType("->")
    @JvmField val FAT_ARROW = RockitTokenType("=>")
    @JvmField val COLON_COLON = RockitTokenType("::")

    // --- Punctuation ---
    @JvmField val DOT = RockitTokenType(".")
    @JvmField val COMMA = RockitTokenType(",")
    @JvmField val COLON = RockitTokenType(":")
    @JvmField val SEMICOLON = RockitTokenType(";")
    @JvmField val LPAREN = RockitTokenType("(")
    @JvmField val RPAREN = RockitTokenType(")")
    @JvmField val LBRACE = RockitTokenType("{")
    @JvmField val RBRACE = RockitTokenType("}")
    @JvmField val LBRACKET = RockitTokenType("[")
    @JvmField val RBRACKET = RockitTokenType("]")
    @JvmField val AT = RockitTokenType("@")
    @JvmField val HASH = RockitTokenType("#")
    @JvmField val UNDERSCORE = RockitTokenType("_")
    @JvmField val BACKSLASH = RockitTokenType("\\")

    // --- Literals ---
    @JvmField val INTEGER_LITERAL = RockitTokenType("INTEGER_LITERAL")
    @JvmField val FLOAT_LITERAL = RockitTokenType("FLOAT_LITERAL")
    @JvmField val STRING_LITERAL = RockitTokenType("STRING_LITERAL")
    @JvmField val STRING_ESCAPE = RockitTokenType("STRING_ESCAPE")
    @JvmField val STRING_INTERPOLATION = RockitTokenType("STRING_INTERPOLATION")
    @JvmField val MULTILINE_STRING_LITERAL = RockitTokenType("MULTILINE_STRING_LITERAL")

    // --- Identifier ---
    @JvmField val IDENTIFIER = RockitTokenType("IDENTIFIER")
    @JvmField val BOOLEAN_IDENTIFIER = RockitTokenType("BOOLEAN_IDENTIFIER")
    @JvmField val BUILTIN_TYPE = RockitTokenType("BUILTIN_TYPE")
    @JvmField val BUILTIN_FUNCTION = RockitTokenType("BUILTIN_FUNCTION")

    // --- Comments ---
    @JvmField val LINE_COMMENT = RockitTokenType("LINE_COMMENT")
    @JvmField val BLOCK_COMMENT = RockitTokenType("BLOCK_COMMENT")

    // --- Annotation ---
    @JvmField val ANNOTATION = RockitTokenType("ANNOTATION")

    // --- Whitespace & special ---
    @JvmField val WHITE_SPACE = com.intellij.psi.TokenType.WHITE_SPACE
    @JvmField val BAD_CHARACTER = com.intellij.psi.TokenType.BAD_CHARACTER
    @JvmField val NEWLINE = RockitTokenType("NEWLINE")

    // --- Token Sets ---
    @JvmField
    val KEYWORDS = TokenSet.create(
        KW_FUN, KW_VAL, KW_VAR, KW_CLASS, KW_INTERFACE, KW_OBJECT, KW_ENUM,
        KW_DATA, KW_SEALED, KW_ABSTRACT, KW_OPEN, KW_OVERRIDE,
        KW_PRIVATE, KW_INTERNAL, KW_PUBLIC, KW_PROTECTED, KW_COMPANION,
        KW_TYPEALIAS, KW_VARARG, KW_IMPORT, KW_PACKAGE,
        KW_THIS, KW_SUPER, KW_CONSTRUCTOR, KW_INIT, KW_WHERE, KW_OUT,
        KW_IF, KW_ELSE, KW_WHEN, KW_FOR, KW_WHILE, KW_DO,
        KW_RETURN, KW_BREAK, KW_CONTINUE, KW_IN, KW_IS, KW_AS,
        KW_THROW, KW_TRY, KW_CATCH, KW_FINALLY,
        KW_TRUE, KW_FALSE, KW_NULL
    )

    @JvmField
    val ROCKIT_KEYWORDS = TokenSet.create(
        KW_VIEW, KW_ACTOR, KW_NAVIGATION, KW_ROUTE, KW_THEME, KW_STYLE,
        KW_SUSPEND, KW_ASYNC, KW_AWAIT, KW_CONCURRENT,
        KW_WEAK, KW_UNOWNED
    )

    @JvmField
    val COMMENTS = TokenSet.create(LINE_COMMENT, BLOCK_COMMENT)

    @JvmField
    val STRINGS = TokenSet.create(STRING_LITERAL, MULTILINE_STRING_LITERAL)

    @JvmField
    val NUMBERS = TokenSet.create(INTEGER_LITERAL, FLOAT_LITERAL)

    @JvmField
    val OPERATORS = TokenSet.create(
        PLUS, MINUS, STAR, SLASH, PERCENT,
        EQ_EQ, BANG_EQ, LT, LT_EQ, GT, GT_EQ,
        AMP_AMP, PIPE_PIPE, BANG,
        EQ, PLUS_EQ, MINUS_EQ, STAR_EQ, SLASH_EQ, PERCENT_EQ,
        QUESTION, QUESTION_DOT, ELVIS, BANG_BANG,
        DOT_DOT, DOT_DOT_LESS, ARROW, FAT_ARROW, COLON_COLON
    )

    @JvmField
    val BRACES = TokenSet.create(LBRACE, RBRACE)

    @JvmField
    val BRACKETS = TokenSet.create(LBRACKET, RBRACKET)

    @JvmField
    val PARENTHESES = TokenSet.create(LPAREN, RPAREN)
}
