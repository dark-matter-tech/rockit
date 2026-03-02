// bench_objects.js — Object allocation benchmark
// Measures: heap allocation, GC pressure, field access

class Point {
    constructor(x, y) {
        this.x = x;
        this.y = y;
    }
}

function addPoints(a, b) {
    return new Point(a.x + b.x, a.y + b.y);
}

let p = new Point(0, 0);
for (let i = 0; i < 1000000; i++) {
    const q = new Point(i, i);
    p = addPoints(p, q);
}
console.log(p.x);
console.log(p.y);
