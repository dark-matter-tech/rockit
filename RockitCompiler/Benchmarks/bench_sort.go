// bench_sort.go — Quicksort benchmark
// Measures: recursion, array operations, partitioning
package main

import "fmt"

func partition(arr []int, lo, hi int) int {
	pivot := arr[hi]
	i := lo
	for j := lo; j < hi; j++ {
		if arr[j] < pivot {
			arr[i], arr[j] = arr[j], arr[i]
			i++
		}
	}
	arr[i], arr[hi] = arr[hi], arr[i]
	return i
}

func quicksort(arr []int, lo, hi int) {
	if lo < hi {
		p := partition(arr, lo, hi)
		quicksort(arr, lo, p-1)
		quicksort(arr, p+1, hi)
	}
}

func main() {
	n := 500000
	arr := make([]int, n)

	seed := 42
	for i := 0; i < n; i++ {
		seed = (seed*1103515245 + 12345) % 2147483648
		arr[i] = seed % 1000000
	}

	quicksort(arr, 0, n-1)

	fmt.Println(arr[0])
	fmt.Println(arr[n/2])
	fmt.Println(arr[n-1])
}
