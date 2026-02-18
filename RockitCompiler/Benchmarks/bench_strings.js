// bench_strings.js — String operations benchmark
// Measures: string concatenation, memory handling

let s = "";
for (let i = 0; i < 100000; i++) {
    s += "x";
}
console.log(s.length);
