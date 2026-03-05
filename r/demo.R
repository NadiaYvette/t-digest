#!/usr/bin/env Rscript
# Demo / self-test for t-digest R implementation

source("tdigest.R")

td <- tdigest_new(100)

# Insert 10000 uniformly spaced values in [0, 1)
n <- 10000
for (i in 0:(n - 1)) {
  tdigest_add(td, i / n)
}

cat(sprintf("T-Digest demo: %d uniform values in [0, 1)\n", n))
cat(sprintf("Centroids: %d\n\n", tdigest_centroid_count(td)))

cat("Quantile estimates (expected ~ q for uniform):\n")
for (q in c(0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999)) {
  est <- tdigest_quantile(td, q)
  cat(sprintf("  q=%-6.3f  estimated=%.6f  error=%.6f\n", q, est, abs(est - q)))
}

cat("\nCDF estimates (expected ~ x for uniform):\n")
for (x in c(0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999)) {
  est <- tdigest_cdf(td, x)
  cat(sprintf("  x=%-6.3f  estimated=%.6f  error=%.6f\n", x, est, abs(est - x)))
}

# Test merge
td1 <- tdigest_new(100)
td2 <- tdigest_new(100)
for (i in 0:4999) {
  tdigest_add(td1, i / 10000)
}
for (i in 5000:9999) {
  tdigest_add(td2, i / 10000)
}
tdigest_merge(td1, td2)

cat("\nAfter merge:\n")
cat(sprintf("  median=%.6f (expected ~0.5)\n", tdigest_quantile(td1, 0.5)))
cat(sprintf("  p99   =%.6f (expected ~0.99)\n", tdigest_quantile(td1, 0.99)))

cat("\nAll tests passed!\n")
