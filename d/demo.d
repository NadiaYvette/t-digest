// Demo / self-test for t-digest D implementation

import std.stdio;
import std.math;
import tdigest;

void main() {
    auto td = TDigest.create(100.0);
    enum n = 10000;

    foreach (i; 0 .. n) {
        td.add(cast(double)(i) / cast(double)(n));
    }

    writefln("T-Digest demo: %d uniform values in [0, 1)", n);
    writefln("Centroids: %d", td.centroidCount());
    writeln();

    writeln("Quantile estimates (expected ~ q for uniform):");
    foreach (q; [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999]) {
        double est = td.quantile(q);
        writefln("  q=%-6.3f  estimated=%.6f  error=%.6f", q, est, fabs(est - q));
    }

    writeln();
    writeln("CDF estimates (expected ~ x for uniform):");
    foreach (x; [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999]) {
        double est = td.cdf(x);
        writefln("  x=%-6.3f  estimated=%.6f  error=%.6f", x, est, fabs(est - x));
    }

    // Test merge
    auto td1 = TDigest.create(100.0);
    auto td2 = TDigest.create(100.0);
    foreach (i; 0 .. 5000) {
        td1.add(cast(double)(i) / 10000.0);
    }
    foreach (i; 5000 .. 10000) {
        td2.add(cast(double)(i) / 10000.0);
    }
    td1.merge(td2);

    writeln();
    writeln("After merge:");
    writefln("  median=%.6f (expected ~0.5)", td1.quantile(0.5));
    writefln("  p99   =%.6f (expected ~0.99)", td1.quantile(0.99));
}
