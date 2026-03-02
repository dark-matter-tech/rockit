// bench_sort.rs — Quicksort benchmark
// Measures: recursion, array operations, partitioning

fn partition(arr: &mut [i64], lo: usize, hi: usize) -> usize {
    let pivot = arr[hi];
    let mut i = lo;
    for j in lo..hi {
        if arr[j] < pivot {
            arr.swap(i, j);
            i += 1;
        }
    }
    arr.swap(i, hi);
    i
}

fn quicksort(arr: &mut [i64], lo: usize, hi: usize) {
    if lo < hi {
        let p = partition(arr, lo, hi);
        if p > 0 {
            quicksort(arr, lo, p - 1);
        }
        quicksort(arr, p + 1, hi);
    }
}

fn main() {
    let n: usize = 500_000;
    let mut arr = vec![0i64; n];

    let mut seed: i64 = 42;
    for i in 0..n {
        seed = (seed.wrapping_mul(1103515245) + 12345) % 2147483648;
        arr[i] = seed % 1000000;
    }

    quicksort(&mut arr, 0, n - 1);

    println!("{}", arr[0]);
    println!("{}", arr[n / 2]);
    println!("{}", arr[n - 1]);
}
