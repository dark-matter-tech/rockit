// bench_sieve.js — Sieve of Eratosthenes
// Measures: array indexing, modulo, conditionals, nested loops

const n = 1000000;
const sieve = new Uint8Array(n + 1).fill(1);
sieve[0] = 0;
sieve[1] = 0;

for (let i = 2; i * i <= n; i++) {
    if (sieve[i]) {
        for (let j = i * i; j <= n; j += i) {
            sieve[j] = 0;
        }
    }
}

let count = 0;
for (let i = 2; i <= n; i++) {
    if (sieve[i]) count++;
}

console.log(count);
