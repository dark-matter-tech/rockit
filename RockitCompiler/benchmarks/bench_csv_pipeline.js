let seed = 42n;
let totalSum = 0n;
const n = 500000;
const cols = 100;
for (let row = 0; row < n; row++) {
    let col10 = 0n, col50 = 0n, col90 = 0n;
    for (let c = 0; c < cols; c++) {
        seed = (seed * 1103515245n + 12345n) % 2147483648n;
        const v = seed % 1000n;
        if (c === 10) col10 = v;
        if (c === 50) col50 = v;
        if (c === 90) col90 = v;
    }
    totalSum += col10 + col50 + col90;
}
console.log(totalSum.toString());
