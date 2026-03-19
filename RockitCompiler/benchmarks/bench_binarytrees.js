// bench_binarytrees.js — Binary Trees (CLBG)
// Single-threaded reference implementation

class Node {
    constructor() {
        this.left = null;
        this.right = null;
    }
}

function bottomUpTree(depth) {
    const n = new Node();
    if (depth > 0) {
        n.left = bottomUpTree(depth - 1);
        n.right = bottomUpTree(depth - 1);
    }
    return n;
}

function itemCheck(node) {
    if (node.left === null) return 1;
    return 1 + itemCheck(node.left) + itemCheck(node.right);
}

function main() {
    const n = 21;
    const minDepth = 4;
    const maxDepth = (minDepth + 2 > n) ? minDepth + 2 : n;
    const stretchDepth = maxDepth + 1;

    const stretchTree = bottomUpTree(stretchDepth);
    console.log("stretch tree of depth " + stretchDepth + "\t check: " + itemCheck(stretchTree));

    const longLivedTree = bottomUpTree(maxDepth);

    for (let depth = minDepth; depth <= maxDepth; depth += 2) {
        const iterations = 1 << (maxDepth - depth + minDepth);
        let check = 0;
        for (let i = 0; i < iterations; i++) {
            const tree = bottomUpTree(depth);
            check += itemCheck(tree);
        }
        console.log(iterations + "\t trees of depth " + depth + "\t check: " + check);
    }

    console.log("long lived tree of depth " + maxDepth + "\t check: " + itemCheck(longLivedTree));
}

main();
