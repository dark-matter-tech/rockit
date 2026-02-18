// bench_sieve.go — Sieve of Eratosthenes
// Measures: array indexing, modulo, conditionals, nested loops
package main

import "fmt"

func main() {
	n := 1000000
	sieve := make([]bool, n+1)
	for i := range sieve {
		sieve[i] = true
	}
	sieve[0] = false
	sieve[1] = false

	for i := 2; i*i <= n; i++ {
		if sieve[i] {
			for j := i * i; j <= n; j += i {
				sieve[j] = false
			}
		}
	}

	count := 0
	for i := 2; i <= n; i++ {
		if sieve[i] {
			count++
		}
	}

	fmt.Println(count)
}
