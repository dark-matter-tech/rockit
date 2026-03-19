// bench_spectralnorm.rs — Spectral Norm (CLBG)
// Single-threaded reference implementation

fn eval_a(i: usize, j: usize) -> usize {
    (i + j) * (i + j + 1) / 2 + i + 1
}

fn eval_a_times_u(n: usize, u: &[f64], au: &mut [f64]) {
    for i in 0..n {
        let mut sum = 0.0_f64;
        for j in 0..n {
            sum += u[j] / eval_a(i, j) as f64;
        }
        au[i] = sum;
    }
}

fn eval_at_times_u(n: usize, u: &[f64], au: &mut [f64]) {
    for i in 0..n {
        let mut sum = 0.0_f64;
        for j in 0..n {
            sum += u[j] / eval_a(j, i) as f64;
        }
        au[i] = sum;
    }
}

fn eval_at_a_times_u(n: usize, u: &[f64], atau: &mut [f64]) {
    let mut v = vec![0.0_f64; n];
    eval_a_times_u(n, u, &mut v);
    eval_at_times_u(n, &v, atau);
}

fn main() {
    let n = 5500;

    let mut u = vec![1.0_f64; n];
    let mut v = vec![0.0_f64; n];

    for _ in 0..10 {
        eval_at_a_times_u(n, &u, &mut v);
        eval_at_a_times_u(n, &v, &mut u);
    }

    let mut v_bv = 0.0_f64;
    let mut vv = 0.0_f64;
    for i in 0..n {
        v_bv += u[i] * v[i];
        vv += v[i] * v[i];
    }

    println!("{:.9}", (v_bv / vv).sqrt());
}
