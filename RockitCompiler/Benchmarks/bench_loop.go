// bench_loop.go — Loop + arithmetic benchmark
// Measures: loop overhead, integer arithmetic, variable mutation
package main

import "fmt"

func main() {
	sum := 0
	for i := 0; i < 100000000; i++ {
		sum += i
	}
	fmt.Println(sum)
}
