// mini_lexer.moon — Proof-of-concept tokenizer written in Moon
// Demonstrates that the runtime has enough primitives for Stage 1 self-hosting.
//
// Tokenizes a simple expression like "val x = 42 + y" into tokens.

fun makeToken(type: String, value: String): Map {
    val tok = mapCreate()
    mapPut(tok, "type", type)
    mapPut(tok, "value", value)
    return tok
}

fun isIdentStart(ch: String): Bool {
    return isLetter(ch)
}

fun isIdentPart(ch: String): Bool {
    return isLetterOrDigit(ch)
}

fun tokenize(source: String): List {
    val tokens = listCreate()
    val len: Int = stringLength(source)
    var pos: Int = 0

    while (pos < len) {
        val ch: String = charAt(source, pos)

        // Skip whitespace
        if (isWhitespace(ch)) {
            pos = pos + 1
            continue
        }

        // Numbers
        if (isDigit(ch)) {
            var numStr: String = ""
            while (pos < len) {
                val c: String = charAt(source, pos)
                if (isDigit(c)) {
                    numStr = stringConcat(numStr, c)
                    pos = pos + 1
                } else {
                    break
                }
            }
            listAppend(tokens, makeToken("INT", numStr))
            continue
        }

        // Identifiers and keywords
        if (isIdentStart(ch)) {
            var ident: String = ""
            while (pos < len) {
                val c: String = charAt(source, pos)
                if (isIdentPart(c)) {
                    ident = stringConcat(ident, c)
                    pos = pos + 1
                } else {
                    break
                }
            }
            // Check keywords
            val keywords = mapCreate()
            mapPut(keywords, "val", "VAL")
            mapPut(keywords, "var", "VAR")
            mapPut(keywords, "fun", "FUN")
            mapPut(keywords, "if", "IF")
            mapPut(keywords, "else", "ELSE")
            mapPut(keywords, "while", "WHILE")
            mapPut(keywords, "return", "RETURN")
            mapPut(keywords, "true", "TRUE")
            mapPut(keywords, "false", "FALSE")

            val kwType = mapGet(keywords, ident)
            if (kwType == null) {
                listAppend(tokens, makeToken("IDENT", ident))
            } else {
                listAppend(tokens, makeToken(toString(kwType), ident))
            }
            continue
        }

        // Single-character operators and punctuation
        if (ch == "+") {
            listAppend(tokens, makeToken("PLUS", "+"))
        } else {
            if (ch == "-") {
                listAppend(tokens, makeToken("MINUS", "-"))
            } else {
                if (ch == "*") {
                    listAppend(tokens, makeToken("STAR", "*"))
                } else {
                    if (ch == "=") {
                        listAppend(tokens, makeToken("EQ", "="))
                    } else {
                        if (ch == "(") {
                            listAppend(tokens, makeToken("LPAREN", "("))
                        } else {
                            if (ch == ")") {
                                listAppend(tokens, makeToken("RPAREN", ")"))
                            } else {
                                if (ch == ":") {
                                    listAppend(tokens, makeToken("COLON", ":"))
                                } else {
                                    listAppend(tokens, makeToken("UNKNOWN", ch))
                                }
                            }
                        }
                    }
                }
            }
        }
        pos = pos + 1
    }

    listAppend(tokens, makeToken("EOF", ""))
    return tokens
}

fun main(): Unit {
    val source: String = "val x = 42 + y"
    println(stringConcat("Tokenizing: ", source))
    println("")

    val tokens = tokenize(source)
    val count: Int = listSize(tokens)

    var i: Int = 0
    while (i < count) {
        val tok = listGet(tokens, i)
        val type: String = toString(mapGet(tok, "type"))
        val value: String = toString(mapGet(tok, "value"))
        println(stringConcat(stringConcat(type, ": "), value))
        i = i + 1
    }

    println("")
    println(stringConcat("Total tokens: ", toString(count)))
}
