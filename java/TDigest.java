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

    public TDigest(double delta) {
        this.delta = delta;
        this.centroids = new ArrayList<>();
        this.buffer = new ArrayList<>();
        this.totalWeight = 0.0;
        this.min = Double.POSITIVE_INFINITY;
        this.max = Double.NEGATIVE_INFINITY;
        this.bufferCap = (int) Math.ceil(delta * BUFFER_FACTOR);
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
    }

    public double quantile(double q) {
        if (!buffer.isEmpty()) compress();
        if (centroids.isEmpty()) return Double.NaN;
        if (centroids.size() == 1) return centroids.get(0).mean;

        if (q < 0.0) q = 0.0;
        if (q > 1.0) q = 1.0;

        double n = totalWeight;
        double target = q * n;
        double cumulative = 0.0;

        for (int i = 0; i < centroids.size(); i++) {
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
        double cumulative = 0.0;

        for (int i = 0; i < centroids.size(); i++) {
            Centroid c = centroids.get(i);

            if (i == 0) {
                if (x < c.mean) {
                    double innerW = c.weight / 2.0;
                    double frac = (c.mean == min) ? 1.0 : (x - min) / (c.mean - min);
                    return (innerW * frac) / n;
                } else if (x == c.mean) {
                    return (c.weight / 2.0) / n;
                }
            }

            if (i == centroids.size() - 1) {
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

            if (x < nextC.mean) {
                if (c.mean == nextC.mean) {
                    return (mid + (nextMid - mid) / 2.0) / n;
                }
                double frac = (x - c.mean) / (nextC.mean - c.mean);
                return (mid + frac * (nextMid - mid)) / n;
            }

            cumulative += c.weight;
        }

        return 1.0;
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
