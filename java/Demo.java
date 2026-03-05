/**
 * Demo and self-test for TDigest.
 */
public class Demo {
    public static void main(String[] args) {
        TDigest td = new TDigest(100);

        int n = 10000;
        for (int i = 0; i < n; i++) {
            td.add((double) i / n);
        }

        System.out.printf("T-Digest demo: %d uniform values in [0, 1)%n", n);
        System.out.printf("Centroids: %d%n", td.centroidCount());
        System.out.println();

        double[] quantiles = {0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999};

        System.out.println("Quantile estimates (expected ~ q for uniform):");
        for (double q : quantiles) {
            double est = td.quantile(q);
            System.out.printf("  q=%-6.3f  estimated=%.6f  error=%.6f%n", q, est, Math.abs(est - q));
        }

        System.out.println();
        System.out.println("CDF estimates (expected ~ x for uniform):");
        for (double x : quantiles) {
            double est = td.cdf(x);
            System.out.printf("  x=%-6.3f  estimated=%.6f  error=%.6f%n", x, est, Math.abs(est - x));
        }

        // Test merge
        TDigest td1 = new TDigest(100);
        TDigest td2 = new TDigest(100);
        for (int i = 0; i < 5000; i++) {
            td1.add((double) i / 10000);
        }
        for (int i = 5000; i < 10000; i++) {
            td2.add((double) i / 10000);
        }
        td1.merge(td2);

        System.out.println();
        System.out.println("After merge:");
        System.out.printf("  median=%.6f (expected ~0.5)%n", td1.quantile(0.5));
        System.out.printf("  p99   =%.6f (expected ~0.99)%n", td1.quantile(0.99));
    }
}
