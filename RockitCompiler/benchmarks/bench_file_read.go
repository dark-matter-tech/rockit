package main

import (
	"bufio"
	"fmt"
	"os"
)

func main() {
	f, err := os.Open(os.Args[1])
	if err != nil {
		panic(err)
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 1024*1024), 1024*1024)
	lines := 0
	bytes := 0
	for scanner.Scan() {
		lines++
		bytes += len(scanner.Bytes()) + 1 // +1 for newline
	}
	fmt.Printf("%d %d\n", lines, bytes)
}
