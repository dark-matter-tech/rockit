// bench_matrix.rs — Matrix multiplication
// Measures: nested loops, array indexing, arithmetic

fn main() {
    let n: usize = 200;

    let mut a = vec![0i64; n * n];
    let mut b = vec![0i64; n * n];
    let mut c = vec![0i64; n * n];

    for i in 0..n * n {
        a[i] = (i % 100) as i64;
        b[i] = ((i * 3 + 7) % 100) as i64;
    }

    for i in 0..n {
        for j in 0..n {
            let mut sum: i64 = 0;
            for k in 0..n {
                sum += a[i * n + k] * b[k * n + j];
            }
            c[i * n + j] = sum;
        }
    }

    let mut checksum: i64 = 0;
    for i in 0..n {
        checksum += c[i * n + i];
    }
    println!("{}", checksum);
}
