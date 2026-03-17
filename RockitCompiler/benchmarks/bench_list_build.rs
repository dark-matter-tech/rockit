fn main() {
    let n: i64 = 500000;
    let mut arr: Vec<i64> = Vec::new();
    for i in 0..n {
        arr.push(i);
    }
    let sum: i64 = arr.iter().sum();
    println!("{}", sum);
}
