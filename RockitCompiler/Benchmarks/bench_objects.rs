// bench_objects.rs — Object allocation benchmark
// Measures: struct allocation, field access

struct Point {
    x: i64,
    y: i64,
}

fn add_points(a: &Point, b: &Point) -> Point {
    Point {
        x: a.x + b.x,
        y: a.y + b.y,
    }
}

fn main() {
    let mut p = Point { x: 0, y: 0 };
    for i in 0..1_000_000i64 {
        let q = Point { x: i, y: i };
        p = add_points(&p, &q);
    }
    println!("{}", p.x);
    println!("{}", p.y);
}
