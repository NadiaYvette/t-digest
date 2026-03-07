import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;

/**
 * Dunning t-digest for online quantile estimation.
 * Merging digest variant with K1 (arcsine) scale function.
 */
public class TDigest {

    public static class Centroid {
        double mean;
        double weight;

        public Centroid(double mean, double weight) {
            this.mean = mean;
            this.weight = weight;
        }
    }

    private static final int DEFAULT_DELTA = 100;
    private static final int BUFFER_FACTOR = 5;

    private final double delta;
    private List<Centroid> centroids;
    private List<Centroid> buffer;
    private double totalWeight;
    private double min;
    private double max;
    private final int bufferCap;
    private double[] fenwick; // Fenwick tree (BIT) over centroid weights

    public TDigest(double delta) {
        this.delta = delta;
        this.centroids = new ArrayList<>();
        this.buffer = new ArrayList<>();
        this.totalWeight = 0.0;
        this.min = Double.POSITIVE_INFINITY;
        this.max = Double.NEGATIVE_INFINITY;
        this.bufferCap = (int) Math.ceil(delta * BUFFER_FACTOR);
        this.fenwick = new double[0];
    }

    public TDigest() {
        this(DEFAULT_DELTA);
    }

    public void add(double value, double weight) {
        buffer.add(new Centroid(value, weight));
        totalWeight += weight;
        if (value < min) min = value;
        if (value > max) max = value;
        if (buffer.size() >= bufferCap) {
            compress();
        }
    }

    public void add(double value) {
        add(value, 1.0);
    }

    public void compress() {
        if (buffer.isEmpty() && centroids.size() <= 1) return;

        List<Centroid> all = new ArrayList<>(centroids.size() + buffer.size());
        all.addAll(centroids);
        all.addAll(buffer);
        buffer = new ArrayList<>();
        all.sort(Comparator.comparingDouble(c -> c.mean));

        List<Centroid> newCentroids = new ArrayList<>();
        newCentroids.add(new Centroid(all.get(0).mean, all.get(0).weight));
        double weightSoFar = 0.0;
        double n = totalWeight;

        for (int i = 1; i < all.size(); i++) {
            Centroid last = newCentroids.get(newCentroids.size() - 1);
            double proposed = last.weight + all.get(i).weight;
            double q0 = weightSoFar / n;
            double q1 = (weightSoFar + proposed) / n;

            if (proposed <= 1 && all.size() > 1) {
                mergeIntoLast(newCentroids, all.get(i));
            } else if (k(q1) - k(q0) <= 1.0) {
                mergeIntoLast(newCentroids, all.get(i));
            } else {
                weightSoFar += last.weight;
                newCentroids.add(new Centroid(all.get(i).mean, all.get(i).weight));
            }
        }

        centroids = newCentroids;
        fenwickBuild();
    }

    public double quantile(double q) {
        if (!buffer.isEmpty()) compress();
        if (centroids.isEmpty()) return Double.NaN;
        if (centroids.size() == 1) return centroids.get(0).mean;

        if (q < 0.0) q = 0.0;
        if (q > 1.0) q = 1.0;

        double n = totalWeight;
        double target = q * n;

        // Use Fenwick tree to find the centroid index in O(log n)
        int i = fenwickFind(target);
        double cumulative = (i > 0) ? fenwickPrefixSum(i - 1) : 0.0;

        Centroid c = centroids.get(i);

        if (i == 0) {
            if (target < c.weight / 2.0) {
                if (c.weight == 1) return min;
                return min + (c.mean - min) * (target / (c.weight / 2.0));
            }
        }

        if (i == centroids.size() - 1) {
            if (target > n - c.weight / 2.0) {
                if (c.weight == 1) return max;
                double remaining = n - c.weight / 2.0;
                return c.mean + (max - c.mean) * ((target - remaining) / (c.weight / 2.0));
            }
            return c.mean;
        }

        Centroid nextC = centroids.get(i + 1);
        double mid = cumulative + c.weight / 2.0;
        double nextMid = cumulative + c.weight + nextC.weight / 2.0;

        if (target <= nextMid) {
            double frac;
            if (nextMid == mid) {
                frac = 0.5;
            } else {
                frac = (target - mid) / (nextMid - mid);
            }
            return c.mean + frac * (nextC.mean - c.mean);
        }

        // Fallback: scan forward from i (should rarely happen)
        cumulative += c.weight;
        for (int j = i + 1; j < centroids.size(); j++) {
            c = centroids.get(j);
            if (j == centroids.size() - 1) {
                if (target > n - c.weight / 2.0) {
                    if (c.weight == 1) return max;
                    double remaining = n - c.weight / 2.0;
                    return c.mean + (max - c.mean) * ((target - remaining) / (c.weight / 2.0));
                }
                return c.mean;
            }
            nextC = centroids.get(j + 1);
            mid = cumulative + c.weight / 2.0;
            nextMid = cumulative + c.weight + nextC.weight / 2.0;
            if (target <= nextMid) {
                double frac;
                if (nextMid == mid) frac = 0.5;
                else frac = (target - mid) / (nextMid - mid);
                return c.mean + frac * (nextC.mean - c.mean);
            }
            cumulative += c.weight;
        }

        return max;
    }

    public double cdf(double x) {
        if (!buffer.isEmpty()) compress();
        if (centroids.isEmpty()) return Double.NaN;
        if (x <= min) return 0.0;
        if (x >= max) return 1.0;

        double n = totalWeight;
        int size = centroids.size();

        // Binary search for the rightmost centroid with mean <= x
        int lo = 0, hi = size - 1, pos = -1;
        while (lo <= hi) {
            int mid2 = (lo + hi) >>> 1;
            if (centroids.get(mid2).mean <= x) {
                pos = mid2;
                lo = mid2 + 1;
            } else {
                hi = mid2 - 1;
            }
        }

        // x is less than the first centroid mean
        if (pos < 0) {
            Centroid c = centroids.get(0);
            double innerW = c.weight / 2.0;
            double frac = (c.mean == min) ? 1.0 : (x - min) / (c.mean - min);
            return (innerW * frac) / n;
        }

        int i = pos;
        Centroid c = centroids.get(i);
        double cumulative = (i > 0) ? fenwickPrefixSum(i - 1) : 0.0;

        if (i == 0) {
            if (x == c.mean) {
                return (c.weight / 2.0) / n;
            }
            // x > c.mean, handled below
        }

        if (i == size - 1) {
            if (x > c.mean) {
                double rightW = n - cumulative - c.weight / 2.0;
                double frac = (max == c.mean) ? 0.0 : (x - c.mean) / (max - c.mean);
                return (cumulative + c.weight / 2.0 + rightW * frac) / n;
            } else {
                return (cumulative + c.weight / 2.0) / n;
            }
        }

        double mid = cumulative + c.weight / 2.0;
        Centroid nextC = centroids.get(i + 1);
        double nextCumulative = cumulative + c.weight;
        double nextMid = nextCumulative + nextC.weight / 2.0;

        if (c.mean == nextC.mean) {
            return (mid + (nextMid - mid) / 2.0) / n;
        }
        double frac = (x - c.mean) / (nextC.mean - c.mean);
        return (mid + frac * (nextMid - mid)) / n;
    }

    public void merge(TDigest other) {
        other.compress();
        for (Centroid c : other.centroids) {
            add(c.mean, c.weight);
        }
    }

    public int centroidCount() {
        if (!buffer.isEmpty()) compress();
        return centroids.size();
    }

    public double totalWeight() {
        return totalWeight;
    }

    public double getMin() {
        return min;
    }

    public double getMax() {
        return max;
    }

    /** Build the Fenwick tree from the current centroids list. */
    private void fenwickBuild() {
        int n = centroids.size();
        fenwick = new double[n + 1]; // 1-indexed
        for (int i = 0; i < n; i++) {
            int j = i + 1; // 1-indexed position
            fenwick[j] += centroids.get(i).weight;
            int parent = j + (j & -j);
            if (parent <= n) {
                fenwick[parent] += fenwick[j];
            }
        }
    }

    /** Return prefix sum of weights for centroids[0..i] (inclusive, 0-indexed). */
    private double fenwickPrefixSum(int i) {
        double sum = 0.0;
        for (int j = i + 1; j > 0; j -= j & -j) {
            sum += fenwick[j];
        }
        return sum;
    }

    /**
     * Find the smallest index i such that the prefix sum of weights[0..i] > target,
     * using O(log n) Fenwick tree traversal.
     * This is the centroid whose cumulative weight range contains 'target'.
     */
    private int fenwickFind(double target) {
        int n = centroids.size();
        int pos = 0;
        // Find the highest power of 2 <= n
        int bitMask = Integer.highestOneBit(n);
        double cumul = 0.0;

        while (bitMask > 0) {
            int next = pos + bitMask;
            if (next <= n && cumul + fenwick[next] <= target) {
                cumul += fenwick[next];
                pos = next;
            }
            bitMask >>= 1;
        }
        // pos is now the last index (1-based) whose prefix sum <= target.
        // The centroid we want is at 0-based index pos (which is pos+1 in 1-based,
        // but we cap it).
        if (pos >= n) pos = n - 1;
        return pos; // 0-indexed
    }

    private double k(double q) {
        return (delta / (2.0 * Math.PI)) * Math.asin(2.0 * q - 1.0);
    }

    private void mergeIntoLast(List<Centroid> centroids, Centroid c) {
        Centroid last = centroids.get(centroids.size() - 1);
        double newWeight = last.weight + c.weight;
        last.mean = (last.mean * last.weight + c.mean * c.weight) / newWeight;
        last.weight = newWeight;
    }
}
