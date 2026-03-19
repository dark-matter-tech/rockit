fn main() {
    // Build 100-column CSV line
    let mut line = String::from("f0");
    for i in 1..100 {
        line.push(',');
        line.push('f');
        line.push_str(&i.to_string());
    }

    let mut count: usize = 0;
    for _ in 0..500_000 {
        count = line.split(',').count();
    }
    println!("{}", count);
}
