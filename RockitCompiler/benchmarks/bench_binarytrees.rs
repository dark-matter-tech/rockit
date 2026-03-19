// bench_binarytrees.rs — Binary Trees (CLBG)
// Single-threaded reference implementation

struct Node {
    left: Option<Box<Node>>,
    right: Option<Box<Node>>,
}

fn bottom_up_tree(depth: i32) -> Box<Node> {
    if depth > 0 {
        Box::new(Node {
            left: Some(bottom_up_tree(depth - 1)),
            right: Some(bottom_up_tree(depth - 1)),
        })
    } else {
        Box::new(Node { left: None, right: None })
    }
}

fn item_check(node: &Node) -> i64 {
    match (&node.left, &node.right) {
        (Some(l), Some(r)) => 1 + item_check(l) + item_check(r),
        _ => 1,
    }
}

fn main() {
    let n = 21;
    let min_depth = 4;
    let max_depth = if min_depth + 2 > n { min_depth + 2 } else { n };
    let stretch_depth = max_depth + 1;

    let stretch_tree = bottom_up_tree(stretch_depth);
    println!("stretch tree of depth {}\t check: {}", stretch_depth, item_check(&stretch_tree));
    drop(stretch_tree);

    let long_lived_tree = bottom_up_tree(max_depth);

    let mut depth = min_depth;
    while depth <= max_depth {
        let iterations = 1 << (max_depth - depth + min_depth);
        let mut check: i64 = 0;
        for _ in 0..iterations {
            let tree = bottom_up_tree(depth);
            check += item_check(&tree);
        }
        println!("{}\t trees of depth {}\t check: {}", iterations, depth, check);
        depth += 2;
    }

    println!("long lived tree of depth {}\t check: {}", max_depth, item_check(&long_lived_tree));
}
