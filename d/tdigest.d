// Dunning t-digest for online quantile estimation.
// Merging digest variant with K_1 (arcsine) scale function.
// Uses an array-backed 2-3-4 tree with monoidal measures.

module tdigest;

import std.math;
import std.algorithm;
import tree234;

struct Centroid {
    double mean;
    double weight;
}

/// Four-component monoidal measure for the 2-3-4 tree.
struct TdMeasure {
    double weight = 0;
    int count = 0;
    double maxMean = -double.infinity;
    double meanWeightSum = 0;
}

/// Traits for Tree234 parameterized on Centroid/TdMeasure.
struct CentroidTraits {
    static TdMeasure measure(const Centroid c) {
        return TdMeasure(c.weight, 1, c.mean, c.mean * c.weight);
    }

    static TdMeasure combine(const TdMeasure a, const TdMeasure b) {
        return TdMeasure(
            a.weight + b.weight,
            a.count + b.count,
            fmax(a.maxMean, b.maxMean),
            a.meanWeightSum + b.meanWeightSum
        );
    }

    static TdMeasure identity() {
        return TdMeasure(0, 0, -double.infinity, 0);
    }

    static int compare(const Centroid a, const Centroid b) {
        if (a.mean < b.mean) return -1;
        if (a.mean > b.mean) return 1;
        return 0;
    }
}

enum DEFAULT_DELTA = 100.0;
private enum BUFFER_FACTOR = 5;

struct TDigest {
    double delta;
    private Tree234!(Centroid, TdMeasure, CentroidTraits) tree;
    private Centroid[] buffer;
    double totalWeight = 0.0;
    double minVal = double.infinity;
    double maxVal = -double.infinity;
    private size_t bufferCap;

    static TDigest create(double delta = DEFAULT_DELTA) {
        TDigest td;
        td.delta = delta;
        td.bufferCap = cast(size_t)(ceil(delta * BUFFER_FACTOR));
        return td;
    }

    private double k(double q) const {
        return (delta / (2.0 * PI)) * asin(2.0 * q - 1.0);
    }

    void compress() {
        if (buffer.length == 0 && tree.size() <= 1)
            return;

        // Collect all centroids from tree and buffer
        Centroid[] all;
        all.reserve(tree.size() + buffer.length);
        auto treeCentroids = tree.collect();
        all ~= treeCentroids;
        all ~= buffer;
        buffer.length = 0;

        all.sort!((a, b) => a.mean < b.mean);

        Centroid[] merged;
        merged.reserve(all.length);
        merged ~= Centroid(all[0].mean, all[0].weight);
        double weightSoFar = 0.0;
        double n = totalWeight;

        foreach (i; 1 .. all.length) {
            double proposed = merged[$ - 1].weight + all[i].weight;
            double q0 = weightSoFar / n;
            double q1 = (weightSoFar + proposed) / n;

            if ((proposed <= 1.0 && all.length > 1) || (k(q1) - k(q0) <= 1.0)) {
                double newWeight = merged[$ - 1].weight + all[i].weight;
                merged[$ - 1].mean = (merged[$ - 1].mean * merged[$ - 1].weight +
                    all[i].mean * all[i].weight) / newWeight;
                merged[$ - 1].weight = newWeight;
            } else {
                weightSoFar += merged[$ - 1].weight;
                merged ~= Centroid(all[i].mean, all[i].weight);
            }
        }

        // Rebuild tree from sorted merged centroids
        tree.buildFromSorted(merged);
    }

    void add(double value, double weight = 1.0) {
        buffer ~= Centroid(value, weight);
        totalWeight += weight;
        if (value < minVal) minVal = value;
        if (value > maxVal) maxVal = value;
        if (buffer.length >= bufferCap)
            compress();
    }

    double quantile(double q) {
        if (buffer.length > 0) compress();

        auto centroids = tree.collect();
        if (centroids.length == 0) return double.nan;
        if (centroids.length == 1) return centroids[0].mean;

        if (q < 0.0) q = 0.0;
        if (q > 1.0) q = 1.0;

        double n = totalWeight;
        double target = q * n;

        double cumulative = 0.0;
        foreach (i, c; centroids) {
            double mid = cumulative + c.weight / 2.0;

            // Left boundary
            if (i == 0 && target < c.weight / 2.0) {
                if (c.weight == 1.0) return minVal;
                return minVal + (c.mean - minVal) * (target / (c.weight / 2.0));
            }

            // Right boundary
            if (i == centroids.length - 1) {
                if (target > n - c.weight / 2.0) {
                    if (c.weight == 1.0) return maxVal;
                    double remaining = n - c.weight / 2.0;
                    return c.mean + (maxVal - c.mean) * ((target - remaining) / (c.weight / 2.0));
                }
                return c.mean;
            }

            // Interpolation
            auto nextC = centroids[i + 1];
            double nextMid = cumulative + c.weight + nextC.weight / 2.0;

            if (target <= nextMid) {
                double frac = (nextMid == mid) ? 0.5 : (target - mid) / (nextMid - mid);
                return c.mean + frac * (nextC.mean - c.mean);
            }

            cumulative += c.weight;
        }

        return maxVal;
    }

    double cdf(double x) {
        if (buffer.length > 0) compress();

        auto centroids = tree.collect();
        if (centroids.length == 0) return double.nan;
        if (x <= minVal) return 0.0;
        if (x >= maxVal) return 1.0;

        double n = totalWeight;
        double cumulative = 0.0;

        foreach (i, c; centroids) {
            if (i == 0) {
                if (x < c.mean) {
                    double innerW = c.weight / 2.0;
                    double frac = (c.mean == minVal) ? 1.0 : (x - minVal) / (c.mean - minVal);
                    return (innerW * frac) / n;
                } else if (x == c.mean) {
                    return (c.weight / 2.0) / n;
                }
            }

            if (i == centroids.length - 1) {
                if (x > c.mean) {
                    double rightW = n - cumulative - c.weight / 2.0;
                    double frac = (maxVal == c.mean) ? 0.0 : (x - c.mean) / (maxVal - c.mean);
                    return (cumulative + c.weight / 2.0 + rightW * frac) / n;
                } else {
                    return (cumulative + c.weight / 2.0) / n;
                }
            }

            double midVal = cumulative + c.weight / 2.0;
            auto nextC = centroids[i + 1];
            double nextCumulative = cumulative + c.weight;
            double nextMid = nextCumulative + nextC.weight / 2.0;

            if (x < nextC.mean) {
                if (c.mean == nextC.mean) {
                    return (midVal + (nextMid - midVal) / 2.0) / n;
                }
                double frac = (x - c.mean) / (nextC.mean - c.mean);
                return (midVal + frac * (nextMid - midVal)) / n;
            }

            cumulative += c.weight;
        }

        return 1.0;
    }

    void merge(ref TDigest other) {
        if (other.buffer.length > 0) other.compress();
        auto otherCentroids = other.tree.collect();
        foreach (c; otherCentroids) {
            add(c.mean, c.weight);
        }
    }

    size_t centroidCount() {
        if (buffer.length > 0) compress();
        return cast(size_t) tree.size();
    }
}
