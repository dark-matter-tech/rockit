// bench_strings.go — String operations benchmark
// Measures: string concatenation, memory handling
package main

import "fmt"

func main() {
	s := ""
	for i := 0; i < 100000; i++ {
		s += "x"
	}
	fmt.Println(len(s))
}
