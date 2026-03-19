use std::io::{BufRead, BufReader};
use std::fs::File;
use std::env;

fn main() {
    let args: Vec<String> = env::args().collect();
    let f = File::open(&args[1]).unwrap();
    let reader = BufReader::new(f);
    let mut lines = 0i64;
    let mut bytes = 0i64;
    for line in reader.lines() {
        let l = line.unwrap();
        lines += 1;
        bytes += l.len() as i64 + 1; // +1 for newline
    }
    println!("{} {}", lines, bytes);
}
