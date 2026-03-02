// bench_binarytrees.go — Binary Trees (CLBG)
// Single-threaded reference implementation
package main

import "fmt"

type Node struct {
	left  *Node
	right *Node
}

func bottomUpTree(depth int) *Node {
	if depth > 0 {
		return &Node{
			left:  bottomUpTree(depth - 1),
			right: bottomUpTree(depth - 1),
		}
	}
	return &Node{}
}

func itemCheck(node *Node) int {
	if node.left == nil {
		return 1
	}
	return 1 + itemCheck(node.left) + itemCheck(node.right)
}

func main() {
	n := 21
	minDepth := 4
	maxDepth := n
	if minDepth+2 > n {
		maxDepth = minDepth + 2
	}
	stretchDepth := maxDepth + 1

	stretchTree := bottomUpTree(stretchDepth)
	fmt.Printf("stretch tree of depth %d\t check: %d\n", stretchDepth, itemCheck(stretchTree))

	longLivedTree := bottomUpTree(maxDepth)

	for depth := minDepth; depth <= maxDepth; depth += 2 {
		iterations := 1 << (maxDepth - depth + minDepth)
		check := 0
		for i := 0; i < iterations; i++ {
			tree := bottomUpTree(depth)
			check += itemCheck(tree)
		}
		fmt.Printf("%d\t trees of depth %d\t check: %d\n", iterations, depth, check)
	}

	fmt.Printf("long lived tree of depth %d\t check: %d\n", maxDepth, itemCheck(longLivedTree))
}
