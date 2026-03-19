#include <cstdio>
#include <string>

int main() {
    std::string line = "f0";
    for (int i = 1; i < 100; i++) {
        line += ",f";
        line += std::to_string(i);
    }

    std::string result;
    for (int iter = 0; iter < 500000; iter++) {
        int fieldIdx = 0;
        size_t start = 0;
        for (size_t j = 0; j < line.size(); j++) {
            if (line[j] == ',') {
                if (fieldIdx == 50) {
                    result = line.substr(start, j - start);
                    break;
                }
                fieldIdx++;
                start = j + 1;
            }
        }
    }
    printf("%s\n", result.c_str());
    return 0;
}
