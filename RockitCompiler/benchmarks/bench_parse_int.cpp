#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <string>

int main() {
    int64_t seed = 42;
    int64_t sum = 0;
    int64_t valid = 0;
    int64_t invalid = 0;
    for (int i = 0; i < 1000000; i++) {
        seed = (seed * 1103515245 + 12345) % 2147483648LL;
        std::string s;
        if (seed % 5 == 0) {
            s = "abc";
        } else {
            s = std::to_string(seed % 1000000);
        }
        char* end;
        int64_t v = strtoll(s.c_str(), &end, 10);
        if (end != s.c_str() && *end == '\0') {
            sum += v;
            valid++;
        } else {
            invalid++;
        }
    }
    printf("%lld %lld %lld\n", sum, valid, invalid);
    return 0;
}
