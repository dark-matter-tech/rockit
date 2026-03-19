#include <cstdio>
#include <cstdint>

struct Point {
    int64_t x, y;
};

Point addPoints(Point a, Point b) {
    return {a.x + b.x, a.y + b.y};
}

int main() {
    Point p = {0, 0};
    for (int64_t i = 0; i < 1000000; i++) {
        Point q = {i, i};
        p = addPoints(p, q);
    }
    printf("%lld\n", p.x);
    printf("%lld\n", p.y);
    return 0;
}
