package com.darkmatter.rockit;

import com.intellij.lexer.FlexLexer;
import com.intellij.psi.tree.IElementType;
import static com.darkmatter.rockit.RockitTokenTypes.*;
import static com.intellij.psi.TokenType.BAD_CHARACTER;
import static com.intellij.psi.TokenType.WHITE_SPACE;

%%

%class RockitLexer
%implements FlexLexer
%unicode
%function advance
%type IElementType

%{
    private int commentDepth = 0;
    private int interpBraceDepth = 0;
    private int interpReturnState = YYINITIAL;

    private static final String[] BOOL_PREFIXES = {"is", "has", "can", "should", "was", "will", "did", "does"};

    private IElementType identifierOrBoolean() {
        String s = yytext().toString();
        for (String p : BOOL_PREFIXES) {
            if (s.length() > p.length() && s.startsWith(p) && Character.isUpperCase(s.charAt(p.length()))) {
                return BOOLEAN_IDENTIFIER;
            }
        }
        return IDENTIFIER;
    }
%}

// Helpers
DIGIT          = [0-9]
HEX_DIGIT      = [0-9a-fA-F]
BIN_DIGIT      = [01]
LETTER         = [a-zA-Z_]
ID_CHAR        = [a-zA-Z0-9_]
WHITE          = [ \t\f]
NEWLINE        = \r\n | \r | \n

// Number patterns
DEC_INT        = {DIGIT} ({DIGIT} | _)*
HEX_INT        = 0 [xX] {HEX_DIGIT} ({HEX_DIGIT} | _)*
BIN_INT        = 0 [bB] {BIN_DIGIT} ({BIN_DIGIT} | _)*
FLOAT          = {DEC_INT} "." {DEC_INT} ([eE] [+-]? {DEC_INT})?
FLOAT_EXP      = {DEC_INT} [eE] [+-]? {DEC_INT}

IDENTIFIER     = {LETTER} {ID_CHAR}*

%state STRING MULTILINE_STRING BLOCK_COMMENT_STATE INTERP_ID INTERP_EXPR

%%

// === INTERP_EXPR-specific: brace depth tracking (must come before shared rules) ===
<INTERP_EXPR> {
    "{"                         { interpBraceDepth++; return LBRACE; }
    "}"                         { interpBraceDepth--; if (interpBraceDepth == 0) { yybegin(interpReturnState); return STRING_INTERPOLATION; } return RBRACE; }
}

// === YYINITIAL-specific: string/comment starts, braces without depth tracking ===
<YYINITIAL> {
    // Block comments (nestable)
    "/*"                        { commentDepth = 1; yybegin(BLOCK_COMMENT_STATE); }

    // Multi-line strings (must come before single-line)
    "\"\"\""                    { yybegin(MULTILINE_STRING); }

    // Single-line strings
    \"                          { yybegin(STRING); }

    // Braces (no depth tracking at top level)
    "{"                         { return LBRACE; }
    "}"                         { return RBRACE; }
}

// === Shared rules for YYINITIAL and INTERP_EXPR ===
<YYINITIAL, INTERP_EXPR> {
    // Whitespace
    {WHITE}+                    { return WHITE_SPACE; }
    {NEWLINE}                   { return NEWLINE; }

    // Line comments
    "//" [^\r\n]*               { return LINE_COMMENT; }

    // Keywords — declaration
    "fun"                       { return KW_FUN; }
    "val"                       { return KW_VAL; }
    "var"                       { return KW_VAR; }
    "class"                     { return KW_CLASS; }
    "interface"                 { return KW_INTERFACE; }
    "object"                    { return KW_OBJECT; }
    "enum"                      { return KW_ENUM; }
    "data"                      { return KW_DATA; }
    "sealed"                    { return KW_SEALED; }
    "abstract"                  { return KW_ABSTRACT; }
    "open"                      { return KW_OPEN; }
    "override"                  { return KW_OVERRIDE; }
    "private"                   { return KW_PRIVATE; }
    "internal"                  { return KW_INTERNAL; }
    "public"                    { return KW_PUBLIC; }
    "protected"                 { return KW_PROTECTED; }
    "companion"                 { return KW_COMPANION; }
    "typealias"                 { return KW_TYPEALIAS; }
    "vararg"                    { return KW_VARARG; }
    "import"                    { return KW_IMPORT; }
    "package"                   { return KW_PACKAGE; }
    "this"                      { return KW_THIS; }
    "super"                     { return KW_SUPER; }
    "constructor"               { return KW_CONSTRUCTOR; }
    "init"                      { return KW_INIT; }
    "where"                     { return KW_WHERE; }
    "out"                       { return KW_OUT; }

    // Keywords — control flow
    "if"                        { return KW_IF; }
    "else"                      { return KW_ELSE; }
    "when"                      { return KW_WHEN; }
    "for"                       { return KW_FOR; }
    "while"                     { return KW_WHILE; }
    "do"                        { return KW_DO; }
    "return"                    { return KW_RETURN; }
    "break"                     { return KW_BREAK; }
    "continue"                  { return KW_CONTINUE; }
    "in"                        { return KW_IN; }
    "is"                        { return KW_IS; }
    "as"                        { return KW_AS; }
    "throw"                     { return KW_THROW; }
    "try"                       { return KW_TRY; }
    "catch"                     { return KW_CATCH; }
    "finally"                   { return KW_FINALLY; }

    // Keywords — Rockit-specific
    "view"                      { return KW_VIEW; }
    "actor"                     { return KW_ACTOR; }
    "navigation"                { return KW_NAVIGATION; }
    "route"                     { return KW_ROUTE; }
    "theme"                     { return KW_THEME; }
    "style"                     { return KW_STYLE; }
    "suspend"                   { return KW_SUSPEND; }
    "async"                     { return KW_ASYNC; }
    "await"                     { return KW_AWAIT; }
    "concurrent"                { return KW_CONCURRENT; }
    "weak"                      { return KW_WEAK; }
    "unowned"                   { return KW_UNOWNED; }

    // Keywords — literals
    "true"                      { return KW_TRUE; }
    "false"                     { return KW_FALSE; }
    "null"                      { return KW_NULL; }

    // Annotations (@Name)
    "@" {IDENTIFIER}            { return ANNOTATION; }

    // Numbers (order matters: hex/bin before decimal, float before int)
    {HEX_INT}                   { return INTEGER_LITERAL; }
    {BIN_INT}                   { return INTEGER_LITERAL; }
    {FLOAT}                     { return FLOAT_LITERAL; }
    {FLOAT_EXP}                 { return FLOAT_LITERAL; }
    {DEC_INT}                   { return INTEGER_LITERAL; }

    // Multi-char operators (must come before single-char)
    "=="                        { return EQ_EQ; }
    "!="                        { return BANG_EQ; }
    "<="                        { return LT_EQ; }
    ">="                        { return GT_EQ; }
    "&&"                        { return AMP_AMP; }
    "||"                        { return PIPE_PIPE; }
    "+="                        { return PLUS_EQ; }
    "-="                        { return MINUS_EQ; }
    "*="                        { return STAR_EQ; }
    "/="                        { return SLASH_EQ; }
    "%="                        { return PERCENT_EQ; }
    "?."                        { return QUESTION_DOT; }
    "?:"                        { return ELVIS; }
    "!!"                        { return BANG_BANG; }
    "..<"                       { return DOT_DOT_LESS; }
    ".."                        { return DOT_DOT; }
    "->"                        { return ARROW; }
    "=>"                        { return FAT_ARROW; }
    "::"                        { return COLON_COLON; }

    // Single-char operators
    "+"                         { return PLUS; }
    "-"                         { return MINUS; }
    "*"                         { return STAR; }
    "/"                         { return SLASH; }
    "%"                         { return PERCENT; }
    "="                         { return EQ; }
    "<"                         { return LT; }
    ">"                         { return GT; }
    "!"                         { return BANG; }
    "?"                         { return QUESTION; }

    // Punctuation
    "."                         { return DOT; }
    ","                         { return COMMA; }
    ":"                         { return COLON; }
    ";"                         { return SEMICOLON; }
    "("                         { return LPAREN; }
    ")"                         { return RPAREN; }
    "["                         { return LBRACKET; }
    "]"                         { return RBRACKET; }
    "@"                         { return AT; }
    "#"                         { return HASH; }
    "\\"                        { return BACKSLASH; }

    // Underscore (before identifier so "_" alone is not an identifier)
    "_"                         { return UNDERSCORE; }

    // Built-in types (must come before general identifiers)
    "Int" | "Int8" | "Int16" | "Int32" | "Int64"
    | "UInt" | "UInt8" | "UInt16" | "UInt32" | "UInt64"
    | "Float" | "Double" | "Bool" | "String" | "Char"
    | "Any" | "Unit" | "Nothing" | "Void"
    | "List" | "Map" | "Set" | "Array" | "Pair" | "Triple"
    | "Result" | "Optional" | "Sequence" | "Iterable"
    | "Comparable" | "Throwable" | "Error" | "Exception"
                                { return BUILTIN_TYPE; }

    // Built-in functions
    "println" | "print" | "readLine" | "assert"
    | "listOf" | "mapOf" | "setOf" | "arrayOf"
    | "mutableListOf" | "mutableMapOf" | "mutableSetOf"
    | "maxOf" | "minOf" | "repeat" | "TODO"
    | "require" | "check" | "error"
                                { return BUILTIN_FUNCTION; }

    // Identifiers (must come after keywords and built-in types)
    // Boolean-prefixed identifiers (is..., has..., can..., etc.) detected via Java code
    {IDENTIFIER}                { return identifierOrBoolean(); }

    // Fallback
    [^]                         { return BAD_CHARACTER; }
}

// === INTERP_ID: lex one identifier after $, then return to string state ===
<INTERP_ID> {
    {IDENTIFIER}                { yybegin(interpReturnState); return identifierOrBoolean(); }
    [^]                         { yypushback(1); yybegin(interpReturnState); }
}

// === STRING state ===
<STRING> {
    \"                          { yybegin(YYINITIAL); return STRING_LITERAL; }
    \\\\ | \\\" | \\n | \\t | \\r | \\0 | \\\'
                                { return STRING_ESCAPE; }
    "\\u{" {HEX_DIGIT}+ "}"    { return STRING_ESCAPE; }
    "\\$"                       { return STRING_ESCAPE; }
    "${"                        { interpBraceDepth = 1; interpReturnState = STRING; yybegin(INTERP_EXPR); return STRING_INTERPOLATION; }
    "$" / [a-zA-Z_]             { interpReturnState = STRING; yybegin(INTERP_ID); return STRING_INTERPOLATION; }
    {NEWLINE}                   { yybegin(YYINITIAL); return BAD_CHARACTER; }
    [^\"\\\$\r\n]+              { return STRING_LITERAL; }
    "$"                         { return STRING_LITERAL; }
    [^]                         { return BAD_CHARACTER; }
}

// === MULTILINE_STRING state ===
<MULTILINE_STRING> {
    "\"\"\""                    { yybegin(YYINITIAL); return MULTILINE_STRING_LITERAL; }
    \\\\ | \\\" | \\n | \\t | \\r | \\0 | \\\'
                                { return STRING_ESCAPE; }
    "\\u{" {HEX_DIGIT}+ "}"    { return STRING_ESCAPE; }
    "\\$"                       { return STRING_ESCAPE; }
    "${"                        { interpBraceDepth = 1; interpReturnState = MULTILINE_STRING; yybegin(INTERP_EXPR); return STRING_INTERPOLATION; }
    "$" / [a-zA-Z_]             { interpReturnState = MULTILINE_STRING; yybegin(INTERP_ID); return STRING_INTERPOLATION; }
    [^\"\\\$]+                  { return MULTILINE_STRING_LITERAL; }
    \"                          { return MULTILINE_STRING_LITERAL; }
    "$"                         { return MULTILINE_STRING_LITERAL; }
    "\\"                        { return MULTILINE_STRING_LITERAL; }
    [^]                         { return BAD_CHARACTER; }
}

// === BLOCK_COMMENT state ===
<BLOCK_COMMENT_STATE> {
    "/*"                        { commentDepth++; }
    "*/"                        { commentDepth--; if (commentDepth == 0) { yybegin(YYINITIAL); return BLOCK_COMMENT; } }
    [^]                         { /* consume */ }
}
