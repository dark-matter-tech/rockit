// moon.io.file — File I/O utility functions

fun readFile(path: String): String {
    return toString(fileRead(path))
}

fun writeFile(path: String, content: String): Bool {
    return fileWrite(path, content)
}

fun exists(path: String): Bool {
    return fileExists(path)
}

fun deleteFile(path: String): Bool {
    return fileDelete(path)
}

// Read a file and split into lines
fun readLines(path: String): List {
    val content = toString(fileRead(path))
    return stringSplit(content, "\n")
}

// Write lines to a file with newline separator
fun writeLines(path: String, lines: List): Bool {
    var content: String = ""
    var i: Int = 0
    while (i < listSize(lines)) {
        if (i > 0) {
            content = stringConcat(content, "\n")
        }
        content = stringConcat(content, toString(listGet(lines, i)))
        i = i + 1
    }
    return fileWrite(path, content)
}
