// bench_fib.js — Fibonacci benchmark (recursive)
// Measures: function call overhead, recursion, integer arithmetic

function fib(n) {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}

const result = fib(40);
console.log(result);
