package main

import (
	"fmt"
	"strings"
	"strconv"
)

func main() {
	parts := make([]string, 100)
	for i := 0; i < 100; i++ {
		parts[i] = "f" + strconv.Itoa(i)
	}
	line := strings.Join(parts, ",")

	result := ""
	for i := 0; i < 500000; i++ {
		fieldIdx := 0
		start := 0
		for j := 0; j < len(line); j++ {
			if line[j] == ',' {
				if fieldIdx == 50 {
					result = line[start:j]
					break
				}
				fieldIdx++
				start = j + 1
			}
		}
		if fieldIdx == 50 && result == "" {
			result = line[start:]
		}
	}
	fmt.Println(result)
}
