// bench_fib.go — Fibonacci benchmark (recursive)
// Measures: function call overhead, recursion, integer arithmetic
package main

import "fmt"

func fib(n int) int {
	if n <= 1 {
		return n
	}
	return fib(n-1) + fib(n-2)
}

func main() {
	result := fib(40)
	fmt.Println(result)
}
