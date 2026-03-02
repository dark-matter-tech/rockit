// bench_matrix.go — Matrix multiplication
// Measures: nested loops, array indexing, arithmetic
package main

import "fmt"

func main() {
	n := 200

	a := make([]int, n*n)
	b := make([]int, n*n)
	c := make([]int, n*n)

	for i := 0; i < n*n; i++ {
		a[i] = i % 100
		b[i] = (i*3 + 7) % 100
	}

	for i := 0; i < n; i++ {
		for j := 0; j < n; j++ {
			sum := 0
			for k := 0; k < n; k++ {
				sum += a[i*n+k] * b[k*n+j]
			}
			c[i*n+j] = sum
		}
	}

	checksum := 0
	for i := 0; i < n; i++ {
		checksum += c[i*n+i]
	}
	fmt.Println(checksum)
}
