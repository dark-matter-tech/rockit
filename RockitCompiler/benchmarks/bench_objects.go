// bench_objects.go — Object allocation benchmark
// Measures: heap allocation, GC pressure, field access
package main

import "fmt"

type Point struct {
	x int
	y int
}

func addPoints(a, b Point) Point {
	return Point{a.x + b.x, a.y + b.y}
}

func main() {
	p := Point{0, 0}
	for i := 0; i < 1000000; i++ {
		q := Point{i, i}
		p = addPoints(p, q)
	}
	fmt.Println(p.x)
	fmt.Println(p.y)
}
