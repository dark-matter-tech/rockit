package main

import "fmt"

func main() {
	n := 500000
	cols := 100
	seed := int64(42)
	totalSum := int64(0)
	for row := 0; row < n; row++ {
		var col10, col50, col90 int64
		for c := 0; c < cols; c++ {
			seed = (seed * 1103515245 + 12345) % 2147483648
			v := seed % 1000
			if c == 10 {
				col10 = v
			}
			if c == 50 {
				col50 = v
			}
			if c == 90 {
				col90 = v
			}
		}
		totalSum += col10 + col50 + col90
	}
	fmt.Println(totalSum)
}
