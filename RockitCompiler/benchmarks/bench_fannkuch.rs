// bench_fannkuch.rs — Fannkuch-Redux (CLBG)
// Single-threaded reference implementation

fn main() {
    let n: usize = 12;
    let mut perm = vec![0usize; n];
    let mut perm1 = vec![0usize; n];
    let mut count = vec![0usize; n];

    for i in 0..n {
        perm1[i] = i;
    }

    let mut max_flips: i32 = 0;
    let mut checksum: i32 = 0;
    let mut perm_count: i32 = 0;
    let mut r = n;

    loop {
        while r != 1 {
            count[r - 1] = r;
            r -= 1;
        }

        perm.copy_from_slice(&perm1);

        let mut flips: i32 = 0;
        let mut k = perm[0];
        while k != 0 {
            let mut lo = 0;
            let mut hi = k;
            while lo < hi {
                perm.swap(lo, hi);
                lo += 1;
                hi -= 1;
            }
            flips += 1;
            k = perm[0];
        }

        if flips > max_flips {
            max_flips = flips;
        }
        if perm_count % 2 == 0 {
            checksum += flips;
        } else {
            checksum -= flips;
        }

        loop {
            if r == n {
                println!("{}", checksum);
                println!("Pfannkuchen({}) = {}", n, max_flips);
                return;
            }
            let perm0 = perm1[0];
            for i in 0..r {
                perm1[i] = perm1[i + 1];
            }
            perm1[r] = perm0;
            count[r] -= 1;
            if count[r] > 0 {
                break;
            }
            r += 1;
        }
        perm_count += 1;
    }
}
