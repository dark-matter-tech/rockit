// bench_spectralnorm.js — Spectral Norm (CLBG)
// Single-threaded reference implementation

function evalA(i, j) {
    return (i + j) * (i + j + 1) / 2 + i + 1;
}

function evalAtimesU(n, u, au) {
    for (let i = 0; i < n; i++) {
        let sum = 0;
        for (let j = 0; j < n; j++) {
            sum += u[j] / evalA(i, j);
        }
        au[i] = sum;
    }
}

function evalAttimesU(n, u, au) {
    for (let i = 0; i < n; i++) {
        let sum = 0;
        for (let j = 0; j < n; j++) {
            sum += u[j] / evalA(j, i);
        }
        au[i] = sum;
    }
}

function evalAtAtimesU(n, u, atau) {
    const v = new Float64Array(n);
    evalAtimesU(n, u, v);
    evalAttimesU(n, v, atau);
}

function main() {
    const n = 5500;

    const u = new Float64Array(n);
    const v = new Float64Array(n);
    for (let i = 0; i < n; i++) {
        u[i] = 1.0;
    }

    for (let i = 0; i < 10; i++) {
        evalAtAtimesU(n, u, v);
        evalAtAtimesU(n, v, u);
    }

    let vBv = 0;
    let vv = 0;
    for (let i = 0; i < n; i++) {
        vBv += u[i] * v[i];
        vv += v[i] * v[i];
    }

    console.log(Math.sqrt(vBv / vv).toFixed(9));
}

main();
