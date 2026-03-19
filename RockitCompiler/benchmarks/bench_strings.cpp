#include <cstdio>
#include <string>

int main() {
    std::string s;
    for (int i = 0; i < 100000; i++) {
        s += "x";
    }
    printf("%zu\n", s.length());
    return 0;
}
