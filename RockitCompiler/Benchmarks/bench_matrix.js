// bench_matrix.js — Matrix multiplication
// Measures: nested loops, array indexing, arithmetic

const n = 200;

const a = new Array(n * n);
const b = new Array(n * n);
const c = new Array(n * n).fill(0);

for (let i = 0; i < n * n; i++) {
    a[i] = i % 100;
    b[i] = (i * 3 + 7) % 100;
}

for (let i = 0; i < n; i++) {
    for (let j = 0; j < n; j++) {
        let sum = 0;
        for (let k = 0; k < n; k++) {
            sum += a[i * n + k] * b[k * n + j];
        }
        c[i * n + j] = sum;
    }
}

let checksum = 0;
for (let i = 0; i < n; i++) {
    checksum += c[i * n + i];
}
console.log(checksum);
