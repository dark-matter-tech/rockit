#include <cstdio>
#include <cstdint>
#include <vector>

void swap(std::vector<int64_t>& arr, int64_t i, int64_t j) {
    int64_t tmp = arr[i];
    arr[i] = arr[j];
    arr[j] = tmp;
}

int64_t partition(std::vector<int64_t>& arr, int64_t lo, int64_t hi) {
    int64_t pivot = arr[hi];
    int64_t i = lo;
    for (int64_t j = lo; j < hi; j++) {
        if (arr[j] < pivot) {
            swap(arr, i, j);
            i++;
        }
    }
    swap(arr, i, hi);
    return i;
}

void quicksort(std::vector<int64_t>& arr, int64_t lo, int64_t hi) {
    if (lo < hi) {
        int64_t p = partition(arr, lo, hi);
        quicksort(arr, lo, p - 1);
        quicksort(arr, p + 1, hi);
    }
}

int main() {
    int64_t n = 500000;
    std::vector<int64_t> arr(n);

    int64_t seed = 42;
    for (int64_t i = 0; i < n; i++) {
        seed = (seed * 1103515245 + 12345) % 2147483648;
        arr[i] = seed % 1000000;
    }

    quicksort(arr, 0, n - 1);

    printf("%lld\n", arr[0]);
    printf("%lld\n", arr[n / 2]);
    printf("%lld\n", arr[n - 1]);
    return 0;
}
