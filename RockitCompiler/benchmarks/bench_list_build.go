package main

import "fmt"

func main() {
	n := 500000
	var arr []int
	for i := 0; i < n; i++ {
		arr = append(arr, i)
	}
	sum := 0
	for _, v := range arr {
		sum += v
	}
	fmt.Println(sum)
}
