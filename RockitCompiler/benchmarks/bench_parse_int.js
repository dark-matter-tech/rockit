let seed = 42n;
let sum = 0n;
let valid = 0;
let invalid = 0;
for (let i = 0; i < 1000000; i++) {
    seed = (seed * 1103515245n + 12345n) % 2147483648n;
    let s;
    if (seed % 5n === 0n) {
        s = "abc";
    } else {
        s = String(seed % 1000000n);
    }
    const v = parseInt(s, 10);
    if (isNaN(v)) {
        invalid++;
    } else {
        sum += BigInt(v);
        valid++;
    }
}
console.log(sum.toString() + " " + valid + " " + invalid);
