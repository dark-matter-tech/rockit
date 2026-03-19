#include <cstdio>
#include <cstdint>

int64_t fib(int64_t n) {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}

int main() {
    printf("%lld\n", fib(40));
    return 0;
}
