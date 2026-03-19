// bench_fannkuch.js — Fannkuch-Redux (CLBG)
// Single-threaded reference implementation

function main() {
    const n = 12;
    const perm = new Array(n);
    const perm1 = new Array(n);
    const count = new Array(n);

    for (let i = 0; i < n; i++) {
        perm1[i] = i;
    }

    let maxFlips = 0;
    let checksum = 0;
    let permCount = 0;
    let r = n;

    for (;;) {
        while (r !== 1) {
            count[r - 1] = r;
            r--;
        }

        for (let i = 0; i < n; i++) {
            perm[i] = perm1[i];
        }

        let flips = 0;
        let k = perm[0];
        while (k !== 0) {
            let lo = 0;
            let hi = k;
            while (lo < hi) {
                const tmp = perm[lo];
                perm[lo] = perm[hi];
                perm[hi] = tmp;
                lo++;
                hi--;
            }
            flips++;
            k = perm[0];
        }

        if (flips > maxFlips) {
            maxFlips = flips;
        }
        if (permCount % 2 === 0) {
            checksum += flips;
        } else {
            checksum -= flips;
        }

        for (;;) {
            if (r === n) {
                console.log(checksum);
                console.log("Pfannkuchen(" + n + ") = " + maxFlips);
                return;
            }
            const perm0 = perm1[0];
            for (let i = 0; i < r; i++) {
                perm1[i] = perm1[i + 1];
            }
            perm1[r] = perm0;
            count[r]--;
            if (count[r] > 0) {
                break;
            }
            r++;
        }
        permCount++;
    }
}

main();
