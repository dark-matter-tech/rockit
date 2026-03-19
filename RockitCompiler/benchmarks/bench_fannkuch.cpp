#include <cstdio>
#include <vector>
#include <algorithm>

int main() {
    int n = 12;
    std::vector<int> perm(n), perm1(n), count(n);

    for (int i = 0; i < n; i++) perm1[i] = i;

    int maxFlips = 0;
    int checksum = 0;
    int permCount = 0;
    int r = n;

    while (true) {
        while (r != 1) {
            count[r - 1] = r;
            r--;
        }

        std::copy(perm1.begin(), perm1.end(), perm.begin());

        int flips = 0;
        int k = perm[0];
        while (k != 0) {
            for (int lo = 0, hi = k; lo < hi; lo++, hi--) {
                std::swap(perm[lo], perm[hi]);
            }
            flips++;
            k = perm[0];
        }

        if (flips > maxFlips) maxFlips = flips;
        if (permCount % 2 == 0) {
            checksum += flips;
        } else {
            checksum -= flips;
        }

        while (true) {
            if (r == n) {
                printf("%d\n", checksum);
                printf("Pfannkuchen(%d) = %d\n", n, maxFlips);
                return 0;
            }
            int perm0 = perm1[0];
            for (int i = 0; i < r; i++) {
                perm1[i] = perm1[i + 1];
            }
            perm1[r] = perm0;
            count[r]--;
            if (count[r] > 0) break;
            r++;
        }
        permCount++;
    }
}
