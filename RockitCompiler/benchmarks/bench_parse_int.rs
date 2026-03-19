fn main() {
    let mut seed: i64 = 42;
    let mut sum: i64 = 0;
    let mut valid: i64 = 0;
    let mut invalid: i64 = 0;
    for _ in 0..1_000_000 {
        seed = (seed.wrapping_mul(1103515245) + 12345) % 2147483648;
        let s = if seed % 5 == 0 {
            "abc".to_string()
        } else {
            (seed % 1000000).to_string()
        };
        match s.parse::<i64>() {
            Ok(v) => { sum += v; valid += 1; }
            Err(_) => { invalid += 1; }
        }
    }
    println!("{} {} {}", sum, valid, invalid);
}
