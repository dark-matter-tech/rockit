package main

import (
	"fmt"
	"strconv"
)

func main() {
	seed := int64(42)
	sum := int64(0)
	valid := 0
	invalid := 0
	for i := 0; i < 1000000; i++ {
		seed = (seed * 1103515245 + 12345) % 2147483648
		var s string
		if seed%5 == 0 {
			s = "abc"
		} else {
			s = strconv.FormatInt(seed%1000000, 10)
		}
		v, err := strconv.Atoi(s)
		if err != nil {
			invalid++
		} else {
			sum += int64(v)
			valid++
		}
	}
	fmt.Printf("%d %d %d\n", sum, valid, invalid)
}
