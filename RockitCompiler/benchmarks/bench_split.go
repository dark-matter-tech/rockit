package main

import (
	"fmt"
	"strings"
	"strconv"
)

func main() {
	// Build 100-column CSV line
	parts := make([]string, 100)
	for i := 0; i < 100; i++ {
		parts[i] = "f" + strconv.Itoa(i)
	}
	line := strings.Join(parts, ",")

	count := 0
	for i := 0; i < 500000; i++ {
		fields := strings.Split(line, ",")
		count = len(fields)
	}
	fmt.Println(count)
}
