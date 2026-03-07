//! Dunning t-digest for online quantile estimation.
//!
//! Merging digest variant with K1 (arcsine) scale function:
//! k(q, delta) = (delta / (2*pi)) * asin(2*q - 1)
//!
//! Uses an array-backed 2-3-4 tree with monoidal measures for O(log n)
//! quantile and CDF queries.

pub mod tree234;

use std::cmp::Ordering;
use std::f64::consts::PI;
use tree234::{Measured, Monoid, Tree234};

/// A centroid representing a cluster of values.
#[derive(Clone, Debug)]
pub struct Centroid {
    pub mean: f64,
    pub weight: f64,
}

/// Four-component monoidal measure for subtree aggregation.
///
/// Tracks total weight, count, maximum mean, and weighted mean sum
/// across all centroids in a subtree.
#[derive(Clone, Debug)]
pub struct TdMeasure {
    pub weight: f64,
    pub count: usize,
    pub max_mean: f64,
    pub mean_weight_sum: f64,
}

impl Default for TdMeasure {
    fn default() -> Self {
        TdMeasure {
            weight: 0.0,
            count: 0,
            max_mean: f64::NEG_INFINITY,
            mean_weight_sum: 0.0,
        }
    }
}

impl Monoid for TdMeasure {
    fn combine(&self, other: &Self) -> Self {
        TdMeasure {
            weight: self.weight + other.weight,
            count: self.count + other.count,
            max_mean: self.max_mean.max(other.max_mean),
            mean_weight_sum: self.mean_weight_sum + other.mean_weight_sum,
        }
    }
}

impl Measured<TdMeasure> for Centroid {
    fn measure(&self) -> TdMeasure {
        TdMeasure {
            weight: self.weight,
            count: 1,
            max_mean: self.mean,
            mean_weight_sum: self.mean * self.weight,
        }
    }
}

const DEFAULT_DELTA: f64 = 100.0;
const AUTO_COMPRESS_FACTOR: usize = 3;

/// Comparison function for centroids: order by mean, break ties by weight.
fn cmp_centroids(a: &Centroid, b: &Centroid) -> Ordering {
    a.mean
        .partial_cmp(&b.mean)
        .unwrap_or(Ordering::Equal)
        .then_with(|| {
            a.weight
                .partial_cmp(&b.weight)
                .unwrap_or(Ordering::Equal)
        })
}

/// A merging t-digest data structure for online quantile estimation.
///
/// Uses a 2-3-4 tree with monoidal measures over centroid weights for
/// O(log n) quantile and CDF queries.
#[derive(Clone)]
pub struct TDigest {
    delta: f64,
    tree: Tree234<Centroid, TdMeasure>,
    total_weight: f64,
    min: f64,
    max: f64,
    uncompressed_count: usize,
}

impl TDigest {
    /// Creates a new TDigest with the given compression parameter.
    pub fn new(delta: f64) -> Self {
        TDigest {
            delta,
            tree: Tree234::new(),
            total_weight: 0.0,
            min: f64::INFINITY,
            max: f64::NEG_INFINITY,
            uncompressed_count: 0,
        }
    }

    /// Creates a new TDigest with the default delta (100).
    pub fn default() -> Self {
        Self::new(DEFAULT_DELTA)
    }

    /// K1 (arcsine) scale function.
    fn k(&self, q: f64) -> f64 {
        (self.delta / (2.0 * PI)) * (2.0 * q - 1.0).asin()
    }

    /// Adds a value with the given weight to the digest.
    pub fn add(&mut self, value: f64, weight: f64) {
        if value < self.min {
            self.min = value;
        }
        if value > self.max {
            self.max = value;
        }
        self.total_weight += weight;

        // Insert as a new centroid into the tree.
        self.tree
            .insert(Centroid { mean: value, weight }, &cmp_centroids);
        self.uncompressed_count += 1;

        // Auto-compress when too many uncompressed insertions.
        if self.uncompressed_count >= AUTO_COMPRESS_FACTOR * (self.delta as usize) {
            self.compress();
        }
    }

    /// Merges the centroids using the greedy merge algorithm with K1 scale function.
    pub fn compress(&mut self) {
        self.uncompressed_count = 0;

        let all = self.tree.to_vec();
        if all.len() <= 1 {
            return;
        }

        // Greedy merge: walk through sorted centroids, merging when K1 allows.
        let mut merged: Vec<Centroid> = Vec::with_capacity(all.len());
        merged.push(Centroid {
            mean: all[0].mean,
            weight: all[0].weight,
        });
        let mut weight_so_far: f64 = 0.0;
        let n = self.total_weight;

        for i in 1..all.len() {
            let last_weight = merged.last().unwrap().weight;
            let proposed = last_weight + all[i].weight;
            let q0 = weight_so_far / n;
            let q1 = (weight_so_far + proposed) / n;

            if proposed <= 1.0 && all.len() > 1 {
                // Always merge singletons.
                Self::merge_into_last(&mut merged, &all[i]);
            } else if self.k(q1) - self.k(q0) <= 1.0 {
                Self::merge_into_last(&mut merged, &all[i]);
            } else {
                weight_so_far += merged.last().unwrap().weight;
                merged.push(Centroid {
                    mean: all[i].mean,
                    weight: all[i].weight,
                });
            }
        }

        // Rebuild tree from merged centroids.
        self.tree.clear();
        for c in merged {
            self.tree.insert(c, &cmp_centroids);
        }
    }

    /// Merges a centroid into the last centroid in the list.
    fn merge_into_last(centroids: &mut [Centroid], c: &Centroid) {
        let last = centroids.last_mut().unwrap();
        let new_weight = last.weight + c.weight;
        last.mean = (last.mean * last.weight + c.mean * c.weight) / new_weight;
        last.weight = new_weight;
    }

    /// Returns the estimated value at quantile q (0 <= q <= 1).
    pub fn quantile(&mut self, q: f64) -> Option<f64> {
        if self.uncompressed_count > 0 {
            self.compress();
        }

        let centroids = self.tree.to_vec();
        if centroids.is_empty() {
            return None;
        }
        if centroids.len() == 1 {
            return Some(centroids[0].mean);
        }

        let q = q.clamp(0.0, 1.0);
        let n = self.total_weight;
        let target = q * n;
        let count = centroids.len();

        // Handle first centroid boundary.
        let first_w = centroids[0].weight;
        if target < first_w / 2.0 {
            if first_w == 1.0 {
                return Some(self.min);
            }
            return Some(self.min + (centroids[0].mean - self.min) * (target / (first_w / 2.0)));
        }

        // Handle last centroid boundary.
        let last_w = centroids[count - 1].weight;
        if target > n - last_w / 2.0 {
            if last_w == 1.0 {
                return Some(self.max);
            }
            let remaining = n - last_w / 2.0;
            return Some(
                centroids[count - 1].mean
                    + (self.max - centroids[count - 1].mean)
                        * ((target - remaining) / (last_w / 2.0)),
            );
        }

        // Walk through centroids to find the bracket containing target.
        // We use the tree's find_by_weight for efficient lookup.
        let weight_fn = |m: &TdMeasure| m.weight;
        let key_weight_fn = |c: &Centroid| c.weight;

        if let Some((_key, _cum_before, idx)) =
            self.tree.find_by_weight(target, &weight_fn, &key_weight_fn)
        {
            // idx is the 0-based index in sorted order.
            let i = idx.min(count - 2); // clamp for interpolation

            let mut cumulative = 0.0;
            for j in 0..i {
                cumulative += centroids[j].weight;
            }

            let c_weight = centroids[i].weight;
            let c_mean = centroids[i].mean;
            let mid = cumulative + c_weight / 2.0;
            let next_c = &centroids[i + 1];
            let next_mid = cumulative + c_weight + next_c.weight / 2.0;

            if target <= mid && i > 0 {
                let mut prev_cumulative = 0.0;
                for j in 0..(i - 1) {
                    prev_cumulative += centroids[j].weight;
                }
                let prev = &centroids[i - 1];
                let prev_mid = prev_cumulative + prev.weight / 2.0;
                let frac = if mid == prev_mid {
                    0.5
                } else {
                    (target - prev_mid) / (mid - prev_mid)
                };
                return Some(prev.mean + frac * (c_mean - prev.mean));
            }

            let frac = if next_mid == mid {
                0.5
            } else {
                (target - mid) / (next_mid - mid)
            };
            Some(c_mean + frac * (next_c.mean - c_mean))
        } else {
            // Fallback: return max.
            Some(self.max)
        }
    }

    /// Returns the estimated CDF value (proportion <= x).
    pub fn cdf(&mut self, x: f64) -> Option<f64> {
        if self.uncompressed_count > 0 {
            self.compress();
        }

        let centroids = self.tree.to_vec();
        if centroids.is_empty() {
            return None;
        }
        if x <= self.min {
            return Some(0.0);
        }
        if x >= self.max {
            return Some(1.0);
        }

        let n = self.total_weight;
        let count = centroids.len();

        // Binary search for the rightmost centroid with mean <= x.
        let pos = centroids.partition_point(|c| c.mean <= x);

        if pos == 0 {
            let c_weight = centroids[0].weight;
            let c_mean = centroids[0].mean;
            let inner_w = c_weight / 2.0;
            let frac = if c_mean == self.min {
                1.0
            } else {
                (x - self.min) / (c_mean - self.min)
            };
            return Some((inner_w * frac) / n);
        }

        let i = pos - 1;
        let c_mean = centroids[i].mean;
        let c_weight = centroids[i].weight;
        let mut cumulative = 0.0;
        for j in 0..i {
            cumulative += centroids[j].weight;
        }

        if i == count - 1 {
            let right_w = n - cumulative - c_weight / 2.0;
            let frac = if self.max == c_mean {
                0.0
            } else {
                (x - c_mean) / (self.max - c_mean)
            };
            return Some((cumulative + c_weight / 2.0 + right_w * frac) / n);
        }

        let mid = cumulative + c_weight / 2.0;
        let next_c_mean = centroids[i + 1].mean;
        let next_c_weight = centroids[i + 1].weight;
        let next_cumulative = cumulative + c_weight;
        let next_mid = next_cumulative + next_c_weight / 2.0;

        if x == c_mean && (i + 1 >= count || x < next_c_mean) {
            return Some(mid / n);
        }

        if c_mean == next_c_mean {
            return Some((mid + (next_mid - mid) / 2.0) / n);
        }
        let frac = (x - c_mean) / (next_c_mean - c_mean);
        Some((mid + frac * (next_mid - mid)) / n)
    }

    /// Merges another TDigest into this one.
    pub fn merge(&mut self, other: &TDigest) {
        let other_centroids = other.tree.to_vec();
        for c in &other_centroids {
            self.add(c.mean, c.weight);
        }
    }

    /// Returns the number of centroids after compressing.
    pub fn centroid_count(&mut self) -> usize {
        if self.uncompressed_count > 0 {
            self.compress();
        }
        self.tree.size()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_basic_quantiles() {
        let mut td = TDigest::new(100.0);
        let n = 10000;
        for i in 0..n {
            td.add(i as f64 / n as f64, 1.0);
        }

        let cases = [
            (0.5, 0.02),
            (0.1, 0.02),
            (0.9, 0.02),
            (0.01, 0.005),
            (0.99, 0.005),
        ];
        for (q, tol) in cases {
            let est = td.quantile(q).unwrap();
            assert!(
                (est - q).abs() < tol,
                "quantile({}) = {}, expected {} +/- {}",
                q,
                est,
                q,
                tol
            );
        }
    }

    #[test]
    fn test_basic_cdf() {
        let mut td = TDigest::new(100.0);
        let n = 10000;
        for i in 0..n {
            td.add(i as f64 / n as f64, 1.0);
        }

        let cases = [(0.5, 0.02), (0.1, 0.02), (0.9, 0.02)];
        for (x, tol) in cases {
            let est = td.cdf(x).unwrap();
            assert!(
                (est - x).abs() < tol,
                "cdf({}) = {}, expected {} +/- {}",
                x,
                est,
                x,
                tol
            );
        }
    }

    #[test]
    fn test_merge() {
        let mut td1 = TDigest::new(100.0);
        let mut td2 = TDigest::new(100.0);
        for i in 0..5000 {
            td1.add(i as f64 / 10000.0, 1.0);
        }
        for i in 5000..10000 {
            td2.add(i as f64 / 10000.0, 1.0);
        }
        td1.merge(&td2);

        let median = td1.quantile(0.5).unwrap();
        assert!(
            (median - 0.5).abs() < 0.02,
            "merged median = {}, expected ~0.5",
            median
        );
    }

    #[test]
    fn test_empty() {
        let mut td = TDigest::new(100.0);
        assert!(td.quantile(0.5).is_none());
        assert!(td.cdf(0.5).is_none());
    }

    #[test]
    fn test_single_value() {
        let mut td = TDigest::new(100.0);
        td.add(42.0, 1.0);
        assert_eq!(td.quantile(0.5).unwrap(), 42.0);
    }

    #[test]
    fn test_centroid_count() {
        let mut td = TDigest::new(100.0);
        for i in 0..10000 {
            td.add(i as f64, 1.0);
        }
        let count = td.centroid_count();
        assert!(count > 0 && count <= 500, "centroid_count = {}", count);
    }
}
