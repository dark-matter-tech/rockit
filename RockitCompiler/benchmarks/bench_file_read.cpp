#include <cstdio>
#include <cstdint>
#include <fstream>
#include <string>

int main(int argc, char* argv[]) {
    std::ifstream f(argv[1]);
    std::string line;
    int64_t lines = 0;
    int64_t bytes = 0;
    while (std::getline(f, line)) {
        lines++;
        bytes += line.size() + 1; // +1 for newline
    }
    printf("%lld %lld\n", lines, bytes);
    return 0;
}
