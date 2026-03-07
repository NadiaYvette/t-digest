import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;

/**
 * Dunning t-digest for online quantile estimation.
 * Merging digest variant with K1 (arcsine) scale function.
 * Backed by a 2-3-4 tree with four-component monoidal measures.
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

    /** Four-component monoidal measure for centroids. */
    static class TdMeasure {
        double weight;
        int count;
        double maxMean;
        double meanWeightSum;

        TdMeasure(double weight, int count, double maxMean, double meanWeightSum) {
            this.weight = weight;
            this.count = count;
            this.maxMean = maxMean;
            this.meanWeightSum = meanWeightSum;
        }
    }

    static final Tree234.Measure<Centroid, TdMeasure> CENTROID_MEASURE = new Tree234.Measure<>() {
        public TdMeasure measure(Centroid c) {
            return new TdMeasure(c.weight, 1, c.mean, c.mean * c.weight);
        }

        public TdMeasure combine(TdMeasure a, TdMeasure b) {
            return new TdMeasure(
                a.weight + b.weight,
                a.count + b.count,
                Math.max(a.maxMean, b.maxMean),
                a.meanWeightSum + b.meanWeightSum
            );
        }

        public TdMeasure identity() {
            return new TdMeasure(0, 0, Double.NEGATIVE_INFINITY, 0);
        }
    };

    static final Tree234.KeyCompare<Centroid> CENTROID_COMPARE =
        (a, b) -> Double.compare(a.mean, b.mean);

    private static final int DEFAULT_DELTA = 100;

    private final double delta;
    private Tree234<Centroid, TdMeasure> tree;
    private List<Centroid> buffer;
    private double totalWeight;
    private double min;
    private double max;
    private final int compressThreshold;

    public TDigest(double delta) {
        this.delta = delta;
        this.tree = new Tree234<>(CENTROID_MEASURE, CENTROID_COMPARE);
        this.tree.setWeightExtractor(m -> m.weight);
        this.buffer = new ArrayList<>();
        this.totalWeight = 0.0;
        this.min = Double.POSITIVE_INFINITY;
        this.max = Double.NEGATIVE_INFINITY;
        this.compressThreshold = (int) (3 * delta);
    }

    public TDigest() {
        this(DEFAULT_DELTA);
    }

    public void add(double value, double weight) {
        if (value < min) min = value;
        if (value > max) max = value;
        totalWeight += weight;

        Centroid incoming = new Centroid(value, weight);

        if (tree.size() == 0) {
            tree.insert(incoming);
            return;
        }

        // Find neighbors
        Tree234.NeighborResult<Centroid> neighbors = tree.findNeighbors(incoming);

        // Try to merge with nearest neighbor that satisfies K1 constraint
        boolean merged = false;

        // Try predecessor
        if (neighbors.pred != null) {
            double cumBefore = neighbors.predCumWeight;
            double q0 = cumBefore / totalWeight;
            double q1 = (cumBefore + neighbors.pred.weight + weight) / totalWeight;
            if (k(q1) - k(q0) <= 1.0 || neighbors.pred.weight + weight <= 1) {
                double newWeight = neighbors.pred.weight + weight;
                double newMean = (neighbors.pred.mean * neighbors.pred.weight + value * weight) / newWeight;
                Centroid updated = new Centroid(newMean, newWeight);
                tree.updateKey(neighbors.predNodeIdx, neighbors.predKeyPos, updated, neighbors.predPath);
                merged = true;
            }
        }

        // Try successor if pred didn't work
        if (!merged && neighbors.succ != null) {
            double cumBefore = neighbors.succCumWeight;
            double q0 = cumBefore / totalWeight;
            double q1 = (cumBefore + neighbors.succ.weight + weight) / totalWeight;
            if (k(q1) - k(q0) <= 1.0 || neighbors.succ.weight + weight <= 1) {
                double newWeight = neighbors.succ.weight + weight;
                double newMean = (neighbors.succ.mean * neighbors.succ.weight + value * weight) / newWeight;
                Centroid updated = new Centroid(newMean, newWeight);
                tree.updateKey(neighbors.succNodeIdx, neighbors.succKeyPos, updated, neighbors.succPath);
                merged = true;
            }
        }

        if (!merged) {
            tree.insert(incoming);
        }

        // Auto-compress when tree gets large
        if (tree.size() > compressThreshold) {
            compress();
        }
    }

    public void add(double value) {
        add(value, 1.0);
    }

    public void compress() {
        if (tree.size() <= 1) return;

        List<Centroid> all = tree.toList();
        // already sorted by mean (in-order traversal)

        tree.clear();
        totalWeight = 0;

        // Re-add with merging via K1
        List<Centroid> newCentroids = new ArrayList<>();
        newCentroids.add(new Centroid(all.get(0).mean, all.get(0).weight));
        double weightSoFar = 0.0;
        double n = 0;
        for (Centroid c : all) {
            n += c.weight;
        }

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

        totalWeight = n;
        for (Centroid c : newCentroids) {
            tree.insert(c);
        }
    }

    public double quantile(double q) {
        if (tree.size() == 0) return Double.NaN;
        if (tree.size() == 1) {
            List<Centroid> list = tree.toList();
            return list.get(0).mean;
        }

        if (q < 0.0) q = 0.0;
        if (q > 1.0) q = 1.0;

        // Use the sorted list approach for correctness (same as original)
        List<Centroid> centroids = tree.toList();
        double n = totalWeight;
        double target = q * n;
        int size = centroids.size();

        // Binary search for the centroid containing target
        double cumulative = 0;
        int i = 0;
        for (; i < size; i++) {
            if (cumulative + centroids.get(i).weight > target) break;
            cumulative += centroids.get(i).weight;
        }
        if (i >= size) i = size - 1;
        // Recalculate cumulative for found index
        cumulative = 0;
        for (int j = 0; j < i; j++) {
            cumulative += centroids.get(j).weight;
        }

        Centroid c = centroids.get(i);

        if (i == 0) {
            if (target < c.weight / 2.0) {
                if (c.weight == 1) return min;
                return min + (c.mean - min) * (target / (c.weight / 2.0));
            }
        }

        if (i == size - 1) {
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

        // Fallback: scan forward
        cumulative += c.weight;
        for (int j = i + 1; j < size; j++) {
            c = centroids.get(j);
            if (j == size - 1) {
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
        if (tree.size() == 0) return Double.NaN;
        if (x <= min) return 0.0;
        if (x >= max) return 1.0;

        List<Centroid> centroids = tree.toList();
        double n = totalWeight;
        int size = centroids.size();

        // Binary search for rightmost centroid with mean <= x
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

        if (pos < 0) {
            Centroid c = centroids.get(0);
            double innerW = c.weight / 2.0;
            double frac = (c.mean == min) ? 1.0 : (x - min) / (c.mean - min);
            return (innerW * frac) / n;
        }

        int i = pos;
        Centroid c = centroids.get(i);
        double cumulative = 0;
        for (int j = 0; j < i; j++) {
            cumulative += centroids.get(j).weight;
        }

        if (i == 0) {
            if (x == c.mean) {
                return (c.weight / 2.0) / n;
            }
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
        List<Centroid> otherCentroids = other.tree.toList();
        for (Centroid c : otherCentroids) {
            add(c.mean, c.weight);
        }
    }

    public int centroidCount() {
        return tree.size();
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
