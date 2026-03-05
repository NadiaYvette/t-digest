/*
 * Demo / self-test for the t-digest C++ implementation.
 */

#include <cstdio>
#include <cmath>
#include "tdigest.hpp"

int main() {
    int n = 10000;
    TDigest td(100.0);

    /* Insert 10000 uniformly spaced values in [0, 1) */
    for (int i = 0; i < n; i++) {
        td.add(static_cast<double>(i) / n);
    }

    printf("T-Digest demo: %d uniform values in [0, 1)\n", n);
    printf("Centroids: %d\n", td.centroidCount());
    printf("\n");

    printf("Quantile estimates (expected ~ q for uniform):\n");
    double quantiles[] = {0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999};
    for (double q : quantiles) {
        double est = td.quantile(q);
        printf("  q=%-6.3f  estimated=%.6f  error=%.6f\n", q, est, std::fabs(est - q));
    }

    printf("\n");
    printf("CDF estimates (expected ~ x for uniform):\n");
    double xs[] = {0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999};
    for (double x : xs) {
        double est = td.cdf(x);
        printf("  x=%-6.3f  estimated=%.6f  error=%.6f\n", x, est, std::fabs(est - x));
    }

    /* Test merge */
    TDigest td1(100.0);
    TDigest td2(100.0);

    for (int i = 0; i < 5000; i++) {
        td1.add(static_cast<double>(i) / 10000.0);
    }
    for (int i = 5000; i < 10000; i++) {
        td2.add(static_cast<double>(i) / 10000.0);
    }

    td1.merge(td2);

    printf("\nAfter merge:\n");
    printf("  median=%.6f (expected ~0.5)\n", td1.quantile(0.5));
    printf("  p99   =%.6f (expected ~0.99)\n", td1.quantile(0.99));

    return 0;
}
