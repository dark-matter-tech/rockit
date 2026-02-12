// lexer.moon — Stage 1 Moon Lexer (self-hosted)
// Full tokenizer for the Moon language, written in Moon.
// Produces a List of token Maps, each with keys: "type", "value", "line", "col".

// ---------------------------------------------------------------------------
// Token constructor
// ---------------------------------------------------------------------------

fun makeToken(type: String, value: String, line: Int, col: Int): Map {
    val tok = mapCreate()
    mapPut(tok, "type", type)
    mapPut(tok, "value", value)
    mapPut(tok, "line", line)
    mapPut(tok, "col", col)
    return tok
}

// ---------------------------------------------------------------------------
// Keyword table — built once, passed into tokenize
// ---------------------------------------------------------------------------

fun buildKeywordMap(): Map {
    val kw = mapCreate()
    // Declaration keywords
    mapPut(kw, "fun", "KW_FUN")
    mapPut(kw, "val", "KW_VAL")
    mapPut(kw, "var", "KW_VAR")
    mapPut(kw, "class", "KW_CLASS")
    mapPut(kw, "interface", "KW_INTERFACE")
    mapPut(kw, "object", "KW_OBJECT")
    mapPut(kw, "enum", "KW_ENUM")
    mapPut(kw, "data", "KW_DATA")
    mapPut(kw, "sealed", "KW_SEALED")
    mapPut(kw, "abstract", "KW_ABSTRACT")
    mapPut(kw, "open", "KW_OPEN")
    mapPut(kw, "override", "KW_OVERRIDE")
    mapPut(kw, "private", "KW_PRIVATE")
    mapPut(kw, "internal", "KW_INTERNAL")
    mapPut(kw, "public", "KW_PUBLIC")
    mapPut(kw, "protected", "KW_PROTECTED")
    mapPut(kw, "companion", "KW_COMPANION")
    mapPut(kw, "typealias", "KW_TYPEALIAS")
    // Moon-specific keywords
    mapPut(kw, "view", "KW_VIEW")
    mapPut(kw, "actor", "KW_ACTOR")
    mapPut(kw, "navigation", "KW_NAVIGATION")
    mapPut(kw, "route", "KW_ROUTE")
    mapPut(kw, "theme", "KW_THEME")
    mapPut(kw, "style", "KW_STYLE")
    mapPut(kw, "suspend", "KW_SUSPEND")
    mapPut(kw, "async", "KW_ASYNC")
    mapPut(kw, "await", "KW_AWAIT")
    mapPut(kw, "concurrent", "KW_CONCURRENT")
    mapPut(kw, "weak", "KW_WEAK")
    mapPut(kw, "unowned", "KW_UNOWNED")
    // Control flow keywords
    mapPut(kw, "if", "KW_IF")
    mapPut(kw, "else", "KW_ELSE")
    mapPut(kw, "when", "KW_WHEN")
    mapPut(kw, "for", "KW_FOR")
    mapPut(kw, "while", "KW_WHILE")
    mapPut(kw, "do", "KW_DO")
    mapPut(kw, "return", "KW_RETURN")
    mapPut(kw, "break", "KW_BREAK")
    mapPut(kw, "continue", "KW_CONTINUE")
    mapPut(kw, "in", "KW_IN")
    mapPut(kw, "is", "KW_IS")
    mapPut(kw, "as", "KW_AS")
    mapPut(kw, "throw", "KW_THROW")
    mapPut(kw, "try", "KW_TRY")
    mapPut(kw, "catch", "KW_CATCH")
    mapPut(kw, "finally", "KW_FINALLY")
    // Type / module keywords
    mapPut(kw, "import", "KW_IMPORT")
    mapPut(kw, "package", "KW_PACKAGE")
    mapPut(kw, "this", "KW_THIS")
    mapPut(kw, "super", "KW_SUPER")
    mapPut(kw, "constructor", "KW_CONSTRUCTOR")
    mapPut(kw, "init", "KW_INIT")
    mapPut(kw, "where", "KW_WHERE")
    mapPut(kw, "out", "KW_OUT")
    // Literal keywords
    mapPut(kw, "true", "BOOL_TRUE")
    mapPut(kw, "false", "BOOL_FALSE")
    mapPut(kw, "null", "NULL")
    return kw
}

// ---------------------------------------------------------------------------
// Lexer state — passed as a Map for mutability
// ---------------------------------------------------------------------------

fun makeLexer(source: String, keywords: Map): Map {
    val lex = mapCreate()
    mapPut(lex, "source", source)
    mapPut(lex, "len", stringLength(source))
    mapPut(lex, "pos", 0)
    mapPut(lex, "line", 1)
    mapPut(lex, "col", 1)
    mapPut(lex, "keywords", keywords)
    mapPut(lex, "tokens", listCreate())
    return lex
}

fun lexPos(lex: Map): Int {
    return toInt(mapGet(lex, "pos"))
}

fun lexLen(lex: Map): Int {
    return toInt(mapGet(lex, "len"))
}

fun lexLine(lex: Map): Int {
    return toInt(mapGet(lex, "line"))
}

fun lexCol(lex: Map): Int {
    return toInt(mapGet(lex, "col"))
}

fun lexSource(lex: Map): String {
    return toString(mapGet(lex, "source"))
}

fun lexTokens(lex: Map): List {
    return mapGet(lex, "tokens")
}

fun lexKeywords(lex: Map): Map {
    return mapGet(lex, "keywords")
}

fun lexAtEnd(lex: Map): Bool {
    return lexPos(lex) >= lexLen(lex)
}

fun lexPeek(lex: Map): String {
    if (lexAtEnd(lex)) {
        return ""
    }
    return charAt(lexSource(lex), lexPos(lex))
}

fun lexPeekAt(lex: Map, offset: Int): String {
    val idx = lexPos(lex) + offset
    if (idx >= lexLen(lex)) {
        return ""
    }
    return charAt(lexSource(lex), idx)
}

fun lexAdvance(lex: Map): String {
    val ch = lexPeek(lex)
    mapPut(lex, "pos", lexPos(lex) + 1)
    if (ch == "\n") {
        mapPut(lex, "line", lexLine(lex) + 1)
        mapPut(lex, "col", 1)
    } else {
        mapPut(lex, "col", lexCol(lex) + 1)
    }
    return ch
}

fun lexEmit(lex: Map, type: String, value: String, line: Int, col: Int): Unit {
    listAppend(lexTokens(lex), makeToken(type, value, line, col))
}

// ---------------------------------------------------------------------------
// Scanning helpers
// ---------------------------------------------------------------------------

fun scanLineComment(lex: Map): Unit {
    // Already consumed "//"
    while (!lexAtEnd(lex)) {
        if (lexPeek(lex) == "\n") {
            break
        }
        lexAdvance(lex)
    }
}

fun scanBlockComment(lex: Map): Unit {
    // Already consumed "/*"
    var depth: Int = 1
    while (!lexAtEnd(lex)) {
        val ch = lexAdvance(lex)
        if (ch == "/" && lexPeek(lex) == "*") {
            lexAdvance(lex)
            depth = depth + 1
        } else {
            if (ch == "*" && lexPeek(lex) == "/") {
                lexAdvance(lex)
                depth = depth - 1
                if (depth == 0) {
                    return
                }
            }
        }
    }
    // Unterminated block comment — could emit error token
}

fun scanString(lex: Map): String {
    // Already consumed opening quote
    var result: String = ""
    while (!lexAtEnd(lex)) {
        val ch = lexAdvance(lex)
        if (ch == "\"") {
            return result
        }
        if (ch == "\\") {
            if (lexAtEnd(lex)) {
                return result
            }
            val esc = lexAdvance(lex)
            if (esc == "n") {
                result = stringConcat(result, "\n")
            } else {
                if (esc == "t") {
                    result = stringConcat(result, "\t")
                } else {
                    if (esc == "r") {
                        result = stringConcat(result, "\r")
                    } else {
                        if (esc == "\\") {
                            result = stringConcat(result, "\\")
                        } else {
                            if (esc == "\"") {
                                result = stringConcat(result, "\"")
                            } else {
                                if (esc == "$") {
                                    result = stringConcat(result, "$")
                                } else {
                                    // Unknown escape — include backslash and char
                                    result = stringConcat(result, stringConcat("\\", esc))
                                }
                            }
                        }
                    }
                }
            }
        } else {
            result = stringConcat(result, ch)
        }
    }
    // Unterminated string
    return result
}

fun scanNumber(lex: Map, startCh: String): Map {
    // Returns a map with "type" (INT_LIT or FLOAT_LIT) and "value"
    val result = mapCreate()
    var num: String = startCh

    // Check for hex (0x) or binary (0b)
    if (startCh == "0" && !lexAtEnd(lex)) {
        val next = lexPeek(lex)
        if (next == "x" || next == "X") {
            num = stringConcat(num, lexAdvance(lex))
            while (!lexAtEnd(lex)) {
                val c = lexPeek(lex)
                if (isDigit(c) || c == "a" || c == "b" || c == "c" || c == "d" || c == "e" || c == "f" || c == "A" || c == "B" || c == "C" || c == "D" || c == "E" || c == "F") {
                    num = stringConcat(num, lexAdvance(lex))
                } else {
                    if (c == "_") {
                        lexAdvance(lex)
                    } else {
                        break
                    }
                }
            }
            mapPut(result, "type", "INT_LIT")
            mapPut(result, "value", num)
            return result
        }
        if (next == "b" || next == "B") {
            num = stringConcat(num, lexAdvance(lex))
            while (!lexAtEnd(lex)) {
                val c = lexPeek(lex)
                if (c == "0" || c == "1") {
                    num = stringConcat(num, lexAdvance(lex))
                } else {
                    if (c == "_") {
                        lexAdvance(lex)
                    } else {
                        break
                    }
                }
            }
            mapPut(result, "type", "INT_LIT")
            mapPut(result, "value", num)
            return result
        }
    }

    // Decimal digits
    while (!lexAtEnd(lex)) {
        val c = lexPeek(lex)
        if (isDigit(c)) {
            num = stringConcat(num, lexAdvance(lex))
        } else {
            if (c == "_") {
                lexAdvance(lex)
            } else {
                break
            }
        }
    }

    // Check for float
    if (!lexAtEnd(lex) && lexPeek(lex) == ".") {
        // Make sure next after dot is a digit (not ".." range operator)
        if (lexPeekAt(lex, 1) != "" && isDigit(lexPeekAt(lex, 1))) {
            num = stringConcat(num, lexAdvance(lex))
            while (!lexAtEnd(lex)) {
                val c = lexPeek(lex)
                if (isDigit(c)) {
                    num = stringConcat(num, lexAdvance(lex))
                } else {
                    if (c == "_") {
                        lexAdvance(lex)
                    } else {
                        break
                    }
                }
            }
            // Exponent
            if (!lexAtEnd(lex)) {
                val e = lexPeek(lex)
                if (e == "e" || e == "E") {
                    num = stringConcat(num, lexAdvance(lex))
                    if (!lexAtEnd(lex)) {
                        val sign = lexPeek(lex)
                        if (sign == "+" || sign == "-") {
                            num = stringConcat(num, lexAdvance(lex))
                        }
                    }
                    while (!lexAtEnd(lex) && isDigit(lexPeek(lex))) {
                        num = stringConcat(num, lexAdvance(lex))
                    }
                }
            }
            mapPut(result, "type", "FLOAT_LIT")
            mapPut(result, "value", num)
            return result
        }
    }

    // Integer exponent (e.g. 1e10)
    if (!lexAtEnd(lex)) {
        val e = lexPeek(lex)
        if (e == "e" || e == "E") {
            num = stringConcat(num, lexAdvance(lex))
            if (!lexAtEnd(lex)) {
                val sign = lexPeek(lex)
                if (sign == "+" || sign == "-") {
                    num = stringConcat(num, lexAdvance(lex))
                }
            }
            while (!lexAtEnd(lex) && isDigit(lexPeek(lex))) {
                num = stringConcat(num, lexAdvance(lex))
            }
            mapPut(result, "type", "FLOAT_LIT")
            mapPut(result, "value", num)
            return result
        }
    }

    mapPut(result, "type", "INT_LIT")
    mapPut(result, "value", num)
    return result
}

fun scanIdentifier(lex: Map, startCh: String): String {
    var ident: String = startCh
    while (!lexAtEnd(lex)) {
        val c = lexPeek(lex)
        if (isLetterOrDigit(c) || c == "_") {
            ident = stringConcat(ident, lexAdvance(lex))
        } else {
            break
        }
    }
    return ident
}

// ---------------------------------------------------------------------------
// Main tokenize function
// ---------------------------------------------------------------------------

fun tokenize(source: String): List {
    val keywords = buildKeywordMap()
    val lex = makeLexer(source, keywords)

    while (!lexAtEnd(lex)) {
        val line = lexLine(lex)
        val col = lexCol(lex)
        val ch = lexAdvance(lex)

        // Whitespace (non-newline)
        if (ch == " " || ch == "\t" || ch == "\r") {
            continue
        }

        // Newline
        if (ch == "\n") {
            lexEmit(lex, "NEWLINE", "\\n", line, col)
            continue
        }

        // Comments
        if (ch == "/") {
            val next = lexPeek(lex)
            if (next == "/") {
                lexAdvance(lex)
                scanLineComment(lex)
                continue
            }
            if (next == "*") {
                lexAdvance(lex)
                scanBlockComment(lex)
                continue
            }
            // Division or /=
            if (next == "=") {
                lexAdvance(lex)
                lexEmit(lex, "SLASH_EQ", "/=", line, col)
                continue
            }
            lexEmit(lex, "SLASH", "/", line, col)
            continue
        }

        // String literals
        if (ch == "\"") {
            val str = scanString(lex)
            lexEmit(lex, "STRING_LIT", str, line, col)
            continue
        }

        // Numbers
        if (isDigit(ch)) {
            val numResult = scanNumber(lex, ch)
            lexEmit(lex, toString(mapGet(numResult, "type")), toString(mapGet(numResult, "value")), line, col)
            continue
        }

        // Identifiers and keywords
        if (isLetter(ch) || ch == "_") {
            val ident = scanIdentifier(lex, ch)
            val kwType = mapGet(lexKeywords(lex), ident)
            if (kwType == null) {
                lexEmit(lex, "IDENT", ident, line, col)
            } else {
                lexEmit(lex, toString(kwType), ident, line, col)
            }
            continue
        }

        // Operators and punctuation
        if (ch == "+") {
            if (lexPeek(lex) == "=") {
                lexAdvance(lex)
                lexEmit(lex, "PLUS_EQ", "+=", line, col)
            } else {
                lexEmit(lex, "PLUS", "+", line, col)
            }
            continue
        }
        if (ch == "-") {
            val next = lexPeek(lex)
            if (next == "=") {
                lexAdvance(lex)
                lexEmit(lex, "MINUS_EQ", "-=", line, col)
            } else {
                if (next == ">") {
                    lexAdvance(lex)
                    lexEmit(lex, "ARROW", "->", line, col)
                } else {
                    lexEmit(lex, "MINUS", "-", line, col)
                }
            }
            continue
        }
        if (ch == "*") {
            if (lexPeek(lex) == "=") {
                lexAdvance(lex)
                lexEmit(lex, "STAR_EQ", "*=", line, col)
            } else {
                lexEmit(lex, "STAR", "*", line, col)
            }
            continue
        }
        if (ch == "%") {
            if (lexPeek(lex) == "=") {
                lexAdvance(lex)
                lexEmit(lex, "PERCENT_EQ", "%=", line, col)
            } else {
                lexEmit(lex, "PERCENT", "%", line, col)
            }
            continue
        }
        if (ch == "=") {
            val next = lexPeek(lex)
            if (next == "=") {
                lexAdvance(lex)
                lexEmit(lex, "EQ_EQ", "==", line, col)
            } else {
                if (next == ">") {
                    lexAdvance(lex)
                    lexEmit(lex, "FAT_ARROW", "=>", line, col)
                } else {
                    lexEmit(lex, "EQ", "=", line, col)
                }
            }
            continue
        }
        if (ch == "!") {
            val next = lexPeek(lex)
            if (next == "=") {
                lexAdvance(lex)
                lexEmit(lex, "BANG_EQ", "!=", line, col)
            } else {
                if (next == "!") {
                    lexAdvance(lex)
                    lexEmit(lex, "BANG_BANG", "!!", line, col)
                } else {
                    lexEmit(lex, "BANG", "!", line, col)
                }
            }
            continue
        }
        if (ch == "<") {
            if (lexPeek(lex) == "=") {
                lexAdvance(lex)
                lexEmit(lex, "LESS_EQ", "<=", line, col)
            } else {
                lexEmit(lex, "LESS", "<", line, col)
            }
            continue
        }
        if (ch == ">") {
            if (lexPeek(lex) == "=") {
                lexAdvance(lex)
                lexEmit(lex, "GREATER_EQ", ">=", line, col)
            } else {
                lexEmit(lex, "GREATER", ">", line, col)
            }
            continue
        }
        if (ch == "&") {
            if (lexPeek(lex) == "&") {
                lexAdvance(lex)
                lexEmit(lex, "AMP_AMP", "&&", line, col)
            } else {
                lexEmit(lex, "AMP", "&", line, col)
            }
            continue
        }
        if (ch == "|") {
            if (lexPeek(lex) == "|") {
                lexAdvance(lex)
                lexEmit(lex, "PIPE_PIPE", "||", line, col)
            } else {
                lexEmit(lex, "PIPE", "|", line, col)
            }
            continue
        }
        if (ch == "?") {
            val next = lexPeek(lex)
            if (next == ".") {
                lexAdvance(lex)
                lexEmit(lex, "QUESTION_DOT", "?.", line, col)
            } else {
                if (next == ":") {
                    lexAdvance(lex)
                    lexEmit(lex, "QUESTION_COLON", "?:", line, col)
                } else {
                    lexEmit(lex, "QUESTION", "?", line, col)
                }
            }
            continue
        }
        if (ch == ".") {
            val next = lexPeek(lex)
            if (next == ".") {
                lexAdvance(lex)
                if (lexPeek(lex) == "<") {
                    lexAdvance(lex)
                    lexEmit(lex, "DOT_DOT_LESS", "..<", line, col)
                } else {
                    lexEmit(lex, "DOT_DOT", "..", line, col)
                }
            } else {
                if (next == "*") {
                    lexAdvance(lex)
                    lexEmit(lex, "DOT_STAR", ".*", line, col)
                } else {
                    lexEmit(lex, "DOT", ".", line, col)
                }
            }
            continue
        }
        if (ch == ":") {
            if (lexPeek(lex) == ":") {
                lexAdvance(lex)
                lexEmit(lex, "COLON_COLON", "::", line, col)
            } else {
                lexEmit(lex, "COLON", ":", line, col)
            }
            continue
        }

        // Single-character tokens
        if (ch == "(") {
            lexEmit(lex, "LPAREN", "(", line, col)
            continue
        }
        if (ch == ")") {
            lexEmit(lex, "RPAREN", ")", line, col)
            continue
        }
        if (ch == "{") {
            lexEmit(lex, "LBRACE", "{", line, col)
            continue
        }
        if (ch == "}") {
            lexEmit(lex, "RBRACE", "}", line, col)
            continue
        }
        if (ch == "[") {
            lexEmit(lex, "LBRACKET", "[", line, col)
            continue
        }
        if (ch == "]") {
            lexEmit(lex, "RBRACKET", "]", line, col)
            continue
        }
        if (ch == ",") {
            lexEmit(lex, "COMMA", ",", line, col)
            continue
        }
        if (ch == ";") {
            lexEmit(lex, "SEMICOLON", ";", line, col)
            continue
        }
        if (ch == "@") {
            lexEmit(lex, "AT", "@", line, col)
            continue
        }
        if (ch == "#") {
            lexEmit(lex, "HASH", "#", line, col)
            continue
        }
        if (ch == "\\") {
            lexEmit(lex, "BACKSLASH", "\\", line, col)
            continue
        }

        // Unknown character
        lexEmit(lex, "ERROR", ch, line, col)
    }

    lexEmit(lex, "EOF", "", lexLine(lex), lexCol(lex))
    return lexTokens(lex)
}

// ---------------------------------------------------------------------------
// Formatting helpers
// ---------------------------------------------------------------------------

fun padRight(s: String, width: Int): String {
    var result: String = s
    while (stringLength(result) < width) {
        result = stringConcat(result, " ")
    }
    return result
}

// ---------------------------------------------------------------------------
// Main — tokenize a file or inline source
// ---------------------------------------------------------------------------

fun main(): Unit {
    val args = processArgs()
    var source: String = ""

    if (listSize(args) > 1) {
        // Read from file
        val filename = toString(listGet(args, 1))
        source = toString(fileRead(filename))
    } else {
        // Demo source
        source = "fun main(): Unit {\n    val x: Int = 42\n    val name = \"hello\"\n    if (x >= 10 && name != \"\") {\n        println(name)\n    }\n}\n"
    }

    val tokens = tokenize(source)
    val count: Int = listSize(tokens)

    var i: Int = 0
    while (i < count) {
        val tok = listGet(tokens, i)
        val type: String = toString(mapGet(tok, "type"))
        val value: String = toString(mapGet(tok, "value"))
        val line: Int = toInt(mapGet(tok, "line"))
        val col: Int = toInt(mapGet(tok, "col"))

        // Skip newlines for cleaner output
        if (type != "NEWLINE") {
            val loc = stringConcat(toString(line), stringConcat(":", toString(col)))
            println(stringConcat(padRight(loc, 8), stringConcat(padRight(type, 20), value)))
        }
        i = i + 1
    }

    println(stringConcat("\nTotal tokens: ", toString(count)))
}
