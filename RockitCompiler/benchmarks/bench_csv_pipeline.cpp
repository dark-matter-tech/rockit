#include <cstdio>
#include <cstdint>

int main() {
    int64_t n = 500000;
    int64_t cols = 100;
    int64_t seed = 42;
    int64_t totalSum = 0;
    for (int64_t row = 0; row < n; row++) {
        int64_t col10 = 0, col50 = 0, col90 = 0;
        for (int64_t c = 0; c < cols; c++) {
            seed = (seed * 1103515245 + 12345) % 2147483648LL;
            int64_t v = seed % 1000;
            if (c == 10) col10 = v;
            if (c == 50) col50 = v;
            if (c == 90) col90 = v;
        }
        totalSum += col10 + col50 + col90;
    }
    printf("%lld\n", totalSum);
    return 0;
}
