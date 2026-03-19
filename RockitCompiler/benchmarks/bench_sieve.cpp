#include <cstdio>
#include <cstdint>
#include <vector>

int main() {
    int64_t n = 1000000;
    std::vector<uint8_t> sieve(n + 1, 1);
    sieve[0] = 0;
    sieve[1] = 0;

    for (int64_t i = 2; i * i <= n; i++) {
        if (sieve[i]) {
            for (int64_t j = i * i; j <= n; j += i) {
                sieve[j] = 0;
            }
        }
    }

    int64_t count = 0;
    for (int64_t i = 2; i <= n; i++) {
        if (sieve[i]) count++;
    }
    printf("%lld\n", count);
    return 0;
}
