// bench_loop.js — Loop + arithmetic benchmark
// Measures: loop overhead, integer arithmetic, variable mutation

let sum = 0;
for (let i = 0; i < 100000000; i++) {
    sum += i;
}
console.log(sum);
