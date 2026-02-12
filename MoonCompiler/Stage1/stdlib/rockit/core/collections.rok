// moon.core.collections — Collection utility functions

// Create a list from variable number of items
fun listOf1(a: Int): List {
    val list = listCreate()
    listAppend(list, a)
    return list
}

fun listOf2(a: Int, b: Int): List {
    val list = listCreate()
    listAppend(list, a)
    listAppend(list, b)
    return list
}

fun listOf3(a: Int, b: Int, c: Int): List {
    val list = listCreate()
    listAppend(list, a)
    listAppend(list, b)
    listAppend(list, c)
    return list
}

// Map a function name over a list (calls the function for each element)
fun listForEach(list: List, action: String): Unit {
    var i: Int = 0
    while (i < listSize(list)) {
        println(toString(listGet(list, i)))
        i = i + 1
    }
}

// Sum all integer elements in a list
fun listSum(list: List): Int {
    var sum: Int = 0
    var i: Int = 0
    while (i < listSize(list)) {
        sum = sum + toInt(listGet(list, i))
        i = i + 1
    }
    return sum
}

// Find the maximum integer in a list
fun listMax(list: List): Int {
    var best: Int = toInt(listGet(list, 0))
    var i: Int = 1
    while (i < listSize(list)) {
        val v = toInt(listGet(list, i))
        if (v > best) { best = v }
        i = i + 1
    }
    return best
}

// Find the minimum integer in a list
fun listMin(list: List): Int {
    var best: Int = toInt(listGet(list, 0))
    var i: Int = 1
    while (i < listSize(list)) {
        val v = toInt(listGet(list, i))
        if (v < best) { best = v }
        i = i + 1
    }
    return best
}

// Reverse a list in place
fun listReverse(list: List): Unit {
    val size = listSize(list)
    var i: Int = 0
    var j: Int = size - 1
    while (i < j) {
        val temp = listGet(list, i)
        listSet(list, i, listGet(list, j))
        listSet(list, j, temp)
        i = i + 1
        j = j - 1
    }
}

// Create a copy of a list
fun listCopy(list: List): List {
    val copy = listCreate()
    var i: Int = 0
    while (i < listSize(list)) {
        listAppend(copy, listGet(list, i))
        i = i + 1
    }
    return copy
}

// Join list elements into a string with separator
fun listJoin(list: List, sep: String): String {
    val size = listSize(list)
    if (size == 0) { return "" }
    var result: String = toString(listGet(list, 0))
    var i: Int = 1
    while (i < size) {
        result = stringConcat(result, stringConcat(sep, toString(listGet(list, i))))
        i = i + 1
    }
    return result
}
