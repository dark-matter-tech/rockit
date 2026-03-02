// bench_fannkuch.go — Fannkuch-Redux (CLBG)
// Single-threaded reference implementation
package main

import "fmt"

func main() {
	n := 12

	perm := make([]int, n)
	perm1 := make([]int, n)
	count := make([]int, n)

	for i := 0; i < n; i++ {
		perm1[i] = i
	}

	maxFlips := 0
	checksum := 0
	permCount := 0
	r := n

	for {
		for r != 1 {
			count[r-1] = r
			r--
		}

		copy(perm, perm1)

		flips := 0
		k := perm[0]
		for k != 0 {
			for lo, hi := 0, k; lo < hi; lo, hi = lo+1, hi-1 {
				perm[lo], perm[hi] = perm[hi], perm[lo]
			}
			flips++
			k = perm[0]
		}

		if flips > maxFlips {
			maxFlips = flips
		}
		if permCount%2 == 0 {
			checksum += flips
		} else {
			checksum -= flips
		}

		for {
			if r == n {
				fmt.Println(checksum)
				fmt.Printf("Pfannkuchen(%d) = %d\n", n, maxFlips)
				return
			}
			perm0 := perm1[0]
			for i := 0; i < r; i++ {
				perm1[i] = perm1[i+1]
			}
			perm1[r] = perm0
			count[r]--
			if count[r] > 0 {
				break
			}
			r++
		}
		permCount++
	}
}
