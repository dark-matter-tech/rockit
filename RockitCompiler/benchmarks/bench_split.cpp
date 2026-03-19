#include <cstdio>
#include <string>

int main() {
    // Build 100-column CSV line
    std::string line = "f0";
    for (int i = 1; i < 100; i++) {
        line += ",f";
        line += std::to_string(i);
    }

    int count = 0;
    for (int iter = 0; iter < 500000; iter++) {
        int fields = 1;
        for (size_t j = 0; j < line.size(); j++) {
            if (line[j] == ',') fields++;
        }
        count = fields;
    }
    printf("%d\n", count);
    return 0;
}
