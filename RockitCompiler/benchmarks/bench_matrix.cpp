#include <cstdio>
#include <cstdint>
#include <vector>

int main() {
    int64_t n = 200;
    int64_t total = n * n;
    std::vector<int64_t> a(total), b(total), c(total, 0);

    for (int64_t i = 0; i < total; i++) {
        a[i] = i % 100;
        b[i] = (i * 3 + 7) % 100;
    }

    for (int64_t i = 0; i < n; i++) {
        for (int64_t j = 0; j < n; j++) {
            int64_t sum = 0;
            for (int64_t k = 0; k < n; k++) {
                sum += a[i * n + k] * b[k * n + j];
            }
            c[i * n + j] = sum;
        }
    }

    int64_t checksum = 0;
    for (int64_t i = 0; i < n; i++) {
        checksum += c[i * n + i];
    }
    printf("%lld\n", checksum);
    return 0;
}
