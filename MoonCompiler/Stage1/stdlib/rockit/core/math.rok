// moon.core.math — Math utility functions

fun square(n: Int): Int {
    return n * n
}

fun cube(n: Int): Int {
    return n * n * n
}

fun power(base: Int, exp: Int): Int {
    if (exp == 0) { return 1 }
    var result: Int = 1
    var i: Int = 0
    while (i < exp) {
        result = result * base
        i = i + 1
    }
    return result
}

fun factorial(n: Int): Int {
    if (n <= 1) { return 1 }
    return n * factorial(n - 1)
}

fun gcd(a: Int, b: Int): Int {
    var x: Int = abs(a)
    var y: Int = abs(b)
    while (y != 0) {
        val temp: Int = y
        y = x % y
        x = temp
    }
    return x
}

fun lcm(a: Int, b: Int): Int {
    if (a == 0 || b == 0) { return 0 }
    return abs(a * b) / gcd(a, b)
}

fun clamp(value: Int, lo: Int, hi: Int): Int {
    if (value < lo) { return lo }
    if (value > hi) { return hi }
    return value
}

fun sign(n: Int): Int {
    if (n > 0) { return 1 }
    if (n < 0) { return -1 }
    return 0
}

fun isEven(n: Int): Bool {
    return n % 2 == 0
}

fun isOdd(n: Int): Bool {
    return n % 2 != 0
}
