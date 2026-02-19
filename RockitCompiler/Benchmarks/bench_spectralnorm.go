// bench_spectralnorm.go — Spectral Norm (CLBG)
// Single-threaded reference implementation
package main

import (
	"fmt"
	"math"
)

func evalA(i, j int) int {
	return (i+j)*(i+j+1)/2 + i + 1
}

func evalAtimesU(n int, u, au []float64) {
	for i := 0; i < n; i++ {
		sum := 0.0
		for j := 0; j < n; j++ {
			sum += u[j] / float64(evalA(i, j))
		}
		au[i] = sum
	}
}

func evalAttimesU(n int, u, au []float64) {
	for i := 0; i < n; i++ {
		sum := 0.0
		for j := 0; j < n; j++ {
			sum += u[j] / float64(evalA(j, i))
		}
		au[i] = sum
	}
}

func evalAtAtimesU(n int, u, atau []float64) {
	v := make([]float64, n)
	evalAtimesU(n, u, v)
	evalAttimesU(n, v, atau)
}

func main() {
	n := 5500

	u := make([]float64, n)
	v := make([]float64, n)
	for i := range u {
		u[i] = 1.0
	}

	for i := 0; i < 10; i++ {
		evalAtAtimesU(n, u, v)
		evalAtAtimesU(n, v, u)
	}

	vBv := 0.0
	vv := 0.0
	for i := 0; i < n; i++ {
		vBv += u[i] * v[i]
		vv += v[i] * v[i]
	}

	fmt.Printf("%0.9f\n", math.Sqrt(vBv/vv))
}
