#include <cstdio>
#include <cstdint>
#include <vector>

int main() {
    int64_t n = 500000;
    std::vector<int64_t> arr;
    for (int64_t i = 0; i < n; i++) {
        arr.push_back(i);
    }
    int64_t sum = 0;
    for (int64_t v : arr) {
        sum += v;
    }
    printf("%lld\n", sum);
    return 0;
}
