/*
 * Demo / self-test for the t-digest C implementation.
 */

#include "tdigest.h"
#include <math.h>
#include <stdio.h>

int main(void) {
  int n = 10000;
  tdigest_t *td = tdigest_new(100.0);

  /* Insert 10000 uniformly spaced values in [0, 1) */
  for (int i = 0; i < n; i++) {
    tdigest_add(td, (double)i / n, 1.0);
  }

  printf("T-Digest demo: %d uniform values in [0, 1)\n", n);
  printf("Centroids: %d\n", tdigest_centroid_count(td));
  printf("\n");

  printf("Quantile estimates (expected ~ q for uniform):\n");
  double quantiles[] = {0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999};
  int nq = sizeof(quantiles) / sizeof(quantiles[0]);
  for (int i = 0; i < nq; i++) {
    double q = quantiles[i];
    double est = tdigest_quantile(td, q);
    printf("  q=%-6.3f  estimated=%.6f  error=%.6f\n", q, est, fabs(est - q));
  }

  printf("\n");
  printf("CDF estimates (expected ~ x for uniform):\n");
  double xs[] = {0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999};
  int nx = sizeof(xs) / sizeof(xs[0]);
  for (int i = 0; i < nx; i++) {
    double x = xs[i];
    double est = tdigest_cdf(td, x);
    printf("  x=%-6.3f  estimated=%.6f  error=%.6f\n", x, est, fabs(est - x));
  }

  tdigest_free(td);

  /* Test merge */
  tdigest_t *td1 = tdigest_new(100.0);
  tdigest_t *td2 = tdigest_new(100.0);

  for (int i = 0; i < 5000; i++) {
    tdigest_add(td1, (double)i / 10000.0, 1.0);
  }
  for (int i = 5000; i < 10000; i++) {
    tdigest_add(td2, (double)i / 10000.0, 1.0);
  }

  tdigest_merge(td1, td2);

  printf("\nAfter merge:\n");
  printf("  median=%.6f (expected ~0.5)\n", tdigest_quantile(td1, 0.5));
  printf("  p99   =%.6f (expected ~0.99)\n", tdigest_quantile(td1, 0.99));

  tdigest_free(td1);
  tdigest_free(td2);

  return 0;
}
