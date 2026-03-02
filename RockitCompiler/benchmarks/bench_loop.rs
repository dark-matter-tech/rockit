// bench_loop.rs — Loop + arithmetic benchmark
// Measures: loop overhead, integer arithmetic, variable mutation

fn main() {
    let mut sum: i64 = 0;
    for i in 0..100_000_000i64 {
        sum += i;
    }
    println!("{}", sum);
}
