#!/usr/bin/env python3
"""Demo / self-test for the t-digest implementation."""

from tdigest import TDigest


def main() -> None:
    td = TDigest(delta=100)

    n = 10_000
    for i in range(n):
        td.add(i / n)

    print(f"T-Digest demo: {n} uniform values in [0, 1)")
    print(f"Centroids: {td.centroid_count()}")
    print()

    print("Quantile estimates (expected ~ q for uniform):")
    for q in [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999]:
        est = td.quantile(q)
        print(f"  q={q:<6.3f}  estimated={est:.6f}  error={abs(est - q):.6f}")

    print()
    print("CDF estimates (expected ~ x for uniform):")
    for x in [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999]:
        est = td.cdf(x)
        print(f"  x={x:<6.3f}  estimated={est:.6f}  error={abs(est - x):.6f}")

    # Test merge
    td1 = TDigest(delta=100)
    td2 = TDigest(delta=100)
    for i in range(5000):
        td1.add(i / 10_000)
    for i in range(5000, 10_000):
        td2.add(i / 10_000)
    td1.merge(td2)

    print()
    print("After merge:")
    print(f"  median={td1.quantile(0.5):.6f} (expected ~0.5)")
    print(f"  p99   ={td1.quantile(0.99):.6f} (expected ~0.99)")


if __name__ == "__main__":
    main()
