// moon.core.strings — String utility functions

fun padLeft(s: String, width: Int, ch: String = " "): String {
    var result: String = s
    while (stringLength(result) < width) {
        result = stringConcat(ch, result)
    }
    return result
}

fun padRight(s: String, width: Int, ch: String = " "): String {
    var result: String = s
    while (stringLength(result) < width) {
        result = stringConcat(result, ch)
    }
    return result
}

fun repeat(s: String, count: Int): String {
    var result: String = ""
    var i: Int = 0
    while (i < count) {
        result = stringConcat(result, s)
        i = i + 1
    }
    return result
}

fun join(items: List, separator: String): String {
    val size = listSize(items)
    if (size == 0) { return "" }
    var result: String = toString(listGet(items, 0))
    var i: Int = 1
    while (i < size) {
        result = stringConcat(result, stringConcat(separator, toString(listGet(items, i))))
        i = i + 1
    }
    return result
}

fun split(s: String, delimiter: String): List {
    return stringSplit(s, delimiter)
}

fun reversed(s: String): String {
    val len = stringLength(s)
    var result: String = ""
    var i: Int = len - 1
    while (i >= 0) {
        result = stringConcat(result, charAt(s, i))
        i = i - 1
    }
    return result
}

fun toUpper(s: String): String {
    return stringToUpper(s)
}

fun toLower(s: String): String {
    return stringToLower(s)
}

fun trim(s: String): String {
    return stringTrim(s)
}

fun contains(s: String, sub: String): Bool {
    return stringContains(s, sub)
}

fun replace(s: String, old: String, new: String): String {
    return stringReplace(s, old, new)
}
