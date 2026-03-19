#include <cstdio>
#include <cmath>
#include <vector>

int evalA(int i, int j) {
    return (i + j) * (i + j + 1) / 2 + i + 1;
}

void evalAtimesU(int n, const std::vector<double>& u, std::vector<double>& au) {
    for (int i = 0; i < n; i++) {
        double sum = 0;
        for (int j = 0; j < n; j++) {
            sum += u[j] / evalA(i, j);
        }
        au[i] = sum;
    }
}

void evalAttimesU(int n, const std::vector<double>& u, std::vector<double>& au) {
    for (int i = 0; i < n; i++) {
        double sum = 0;
        for (int j = 0; j < n; j++) {
            sum += u[j] / evalA(j, i);
        }
        au[i] = sum;
    }
}

void evalAtAtimesU(int n, const std::vector<double>& u, std::vector<double>& atau) {
    std::vector<double> v(n);
    evalAtimesU(n, u, v);
    evalAttimesU(n, v, atau);
}

int main() {
    int n = 5500;
    std::vector<double> u(n, 1.0), v(n);

    for (int i = 0; i < 10; i++) {
        evalAtAtimesU(n, u, v);
        evalAtAtimesU(n, v, u);
    }

    double vBv = 0, vv = 0;
    for (int i = 0; i < n; i++) {
        vBv += u[i] * v[i];
        vv += v[i] * v[i];
    }

    printf("%.9f\n", std::sqrt(vBv / vv));
    return 0;
}
