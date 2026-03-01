// bench_fib.rs — Fibonacci benchmark (recursive)
// Measures: function call overhead, recursion, integer arithmetic

fn fib(n: i64) -> i64 {
    if n <= 1 {
        return n;
    }
    fib(n - 1) + fib(n - 2)
}

fn main() {
    let result = fib(40);
    println!("{}", result);
}
