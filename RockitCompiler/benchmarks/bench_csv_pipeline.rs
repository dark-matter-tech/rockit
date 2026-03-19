fn main() {
    let n: i64 = 500000;
    let cols: i64 = 100;
    let mut seed: i64 = 42;
    let mut total_sum: i64 = 0;
    for _ in 0..n {
        let mut col10: i64 = 0;
        let mut col50: i64 = 0;
        let mut col90: i64 = 0;
        for c in 0..cols {
            seed = (seed.wrapping_mul(1103515245) + 12345) % 2147483648;
            let v = seed % 1000;
            if c == 10 { col10 = v; }
            if c == 50 { col50 = v; }
            if c == 90 { col90 = v; }
        }
        total_sum += col10 + col50 + col90;
    }
    println!("{}", total_sum);
}
