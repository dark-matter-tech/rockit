// bench_sort.js — Quicksort benchmark
// Measures: recursion, array operations, partitioning

function partition(arr, lo, hi) {
    const pivot = arr[hi];
    let i = lo;
    for (let j = lo; j < hi; j++) {
        if (arr[j] < pivot) {
            [arr[i], arr[j]] = [arr[j], arr[i]];
            i++;
        }
    }
    [arr[i], arr[hi]] = [arr[hi], arr[i]];
    return i;
}

function quicksort(arr, lo, hi) {
    if (lo < hi) {
        const p = partition(arr, lo, hi);
        quicksort(arr, lo, p - 1);
        quicksort(arr, p + 1, hi);
    }
}

const n = 500000;
const arr = new Array(n);

let seed = 42;
for (let i = 0; i < n; i++) {
    seed = (seed * 1103515245 + 12345) % 2147483648;
    arr[i] = seed % 1000000;
}

quicksort(arr, 0, n - 1);

console.log(arr[0]);
console.log(arr[n >> 1]);
console.log(arr[n - 1]);
