//! Dunning t-digest for online quantile estimation.
//!
//! Merging digest variant with K1 (arcsine) scale function:
//! k(q, delta) = (delta / (2*pi)) * asin(2*q - 1)

use std::f64::consts::PI;

/// A centroid representing a cluster of values.
#[derive(Clone, Debug)]
pub struct Centroid {
    pub mean: f64,
    pub weight: f64,
}

const DEFAULT_DELTA: f64 = 100.0;
const BUFFER_FACTOR: usize = 5;

/// A merging t-digest data structure for online quantile estimation.
///
/// Uses a Fenwick tree (binary indexed tree) over centroid weights for
/// O(log n) quantile and CDF queries instead of linear scans.
#[derive(Clone, Debug)]
pub struct TDigest {
    delta: f64,
    centroids: Vec<Centroid>,
    buffer: Vec<Centroid>,
    total_weight: f64,
    min: f64,
    max: f64,
    buffer_cap: usize,
    /// Fenwick tree (1-indexed) over centroid weights for O(log n) prefix sums.
    fenwick: Vec<f64>,
}

impl TDigest {
    /// Creates a new TDigest with the given compression parameter.
    pub fn new(delta: f64) -> Self {
        TDigest {
            delta,
            centroids: Vec::new(),
            buffer: Vec::new(),
            total_weight: 0.0,
            min: f64::INFINITY,
            max: f64::NEG_INFINITY,
            buffer_cap: (delta as usize) * BUFFER_FACTOR,
            fenwick: Vec::new(),
        }
    }

    /// Creates a new TDigest with the default delta (100).
    pub fn default() -> Self {
        Self::new(DEFAULT_DELTA)
    }

    /// Adds a value with the given weight to the digest.
    pub fn add(&mut self, value: f64, weight: f64) {
        self.buffer.push(Centroid {
            mean: value,
            weight,
        });
        self.total_weight += weight;
        if value < self.min {
            self.min = value;
        }
        if value > self.max {
            self.max = value;
        }
        if self.buffer.len() >= self.buffer_cap {
            self.compress();
        }
    }

    /// K1 (arcsine) scale function.
    fn k(&self, q: f64) -> f64 {
        (self.delta / (2.0 * PI)) * (2.0 * q - 1.0).asin()
    }

    /// Merges the buffer into the centroid list using the greedy merge algorithm.
    pub fn compress(&mut self) {
        if self.buffer.is_empty() && self.centroids.len() <= 1 {
            return;
        }

        let mut all = Vec::with_capacity(self.centroids.len() + self.buffer.len());
        all.append(&mut self.centroids);
        all.append(&mut self.buffer);
        all.sort_by(|a, b| {
            a.mean
                .partial_cmp(&b.mean)
                .unwrap_or(std::cmp::Ordering::Equal)
        });

        let all_len = all.len();
        let mut new_centroids: Vec<Centroid> = Vec::with_capacity(all_len);
        new_centroids.push(Centroid {
            mean: all[0].mean,
            weight: all[0].weight,
        });
        let mut weight_so_far: f64 = 0.0;
        let n = self.total_weight;

        for i in 1..all_len {
            let last_weight = new_centroids.last().unwrap().weight;
            let proposed = last_weight + all[i].weight;
            let q0 = weight_so_far / n;
            let q1 = (weight_so_far + proposed) / n;

            if proposed <= 1.0 && all_len > 1 {
                Self::merge_into_last(&mut new_centroids, &all[i]);
            } else if self.k(q1) - self.k(q0) <= 1.0 {
                Self::merge_into_last(&mut new_centroids, &all[i]);
            } else {
                weight_so_far += new_centroids.last().unwrap().weight;
                new_centroids.push(Centroid {
                    mean: all[i].mean,
                    weight: all[i].weight,
                });
            }
        }

        self.centroids = new_centroids;
        self.fenwick_build();
    }

    /// Builds the Fenwick tree from the current centroid weights.
    /// Called at the end of every compress().
    fn fenwick_build(&mut self) {
        let n = self.centroids.len();
        // 1-indexed Fenwick tree of size n+1
        self.fenwick = vec![0.0; n + 1];
        for i in 0..n {
            self.fenwick_update(i, self.centroids[i].weight);
        }
    }

    /// Adds `delta` to position `i` (0-indexed) in the Fenwick tree.
    fn fenwick_update(&mut self, i: usize, delta: f64) {
        let mut j = i + 1; // 1-indexed
        while j < self.fenwick.len() {
            self.fenwick[j] += delta;
            j += j & j.wrapping_neg(); // j += lowest set bit
        }
    }

    /// Returns the prefix sum of weights for centroids 0..=i (0-indexed).
    fn fenwick_prefix_sum(&self, i: usize) -> f64 {
        let mut sum = 0.0;
        let mut j = i + 1; // 1-indexed
        while j > 0 {
            sum += self.fenwick[j];
            j -= j & j.wrapping_neg(); // remove lowest set bit
        }
        sum
    }

    /// Finds the smallest index `i` such that prefix_sum(0..=i) >= target.
    /// Uses O(log n) tree descent instead of linear scan.
    fn fenwick_find(&self, target: f64) -> usize {
        let n = self.centroids.len();
        if n == 0 {
            return 0;
        }
        // Find the highest power of 2 <= n
        let mut bit = 1;
        while bit * 2 <= n {
            bit *= 2;
        }
        let mut pos: usize = 0;
        let mut remaining = target;
        while bit > 0 {
            let next = pos + bit;
            if next <= n && self.fenwick[next] < remaining {
                remaining -= self.fenwick[next];
                pos = next;
            }
            bit >>= 1;
        }
        // pos is now the 0-indexed result (pos was 0-based position after last step)
        pos // 0-indexed: prefix_sum(0..=pos) >= target
    }

    /// Merges a centroid into the last centroid in the list.
    fn merge_into_last(centroids: &mut [Centroid], c: &Centroid) {
        let last = centroids.last_mut().unwrap();
        let new_weight = last.weight + c.weight;
        last.mean = (last.mean * last.weight + c.mean * c.weight) / new_weight;
        last.weight = new_weight;
    }

    /// Returns the estimated value at quantile q (0 <= q <= 1).
    ///
    /// Uses the Fenwick tree for O(log n) centroid lookup.
    pub fn quantile(&mut self, q: f64) -> Option<f64> {
        if !self.buffer.is_empty() {
            self.compress();
        }
        if self.centroids.is_empty() {
            return None;
        }
        if self.centroids.len() == 1 {
            return Some(self.centroids[0].mean);
        }

        let q = q.clamp(0.0, 1.0);
        let n = self.total_weight;
        let target = q * n;
        let count = self.centroids.len();

        // Handle first centroid boundary
        let first_w = self.centroids[0].weight;
        if target < first_w / 2.0 {
            if first_w == 1.0 {
                return Some(self.min);
            }
            return Some(
                self.min + (self.centroids[0].mean - self.min) * (target / (first_w / 2.0)),
            );
        }

        // Handle last centroid boundary
        let last_w = self.centroids[count - 1].weight;
        if target > n - last_w / 2.0 {
            if last_w == 1.0 {
                return Some(self.max);
            }
            let remaining = n - last_w / 2.0;
            return Some(
                self.centroids[count - 1].mean
                    + (self.max - self.centroids[count - 1].mean)
                        * ((target - remaining) / (last_w / 2.0)),
            );
        }

        // Use Fenwick tree to find the centroid whose cumulative weight
        // neighborhood contains the target. We want the centroid i such that
        // mid_i <= target <= mid_{i+1}, where mid_i = cumulative(0..i) + w_i/2.
        //
        // fenwick_find(target) gives the smallest index whose prefix sum >= target.
        // We need the index where the midpoint bracket contains target.
        let i = self.fenwick_find(target);
        // Clamp to valid range for interpolation (need i and i+1)
        let i = if i >= count - 1 { count - 2 } else { i };

        let cumulative = if i == 0 {
            0.0
        } else {
            self.fenwick_prefix_sum(i - 1)
        };
        let c_weight = self.centroids[i].weight;
        let c_mean = self.centroids[i].mean;
        let mid = cumulative + c_weight / 2.0;
        let next_c = &self.centroids[i + 1];
        let next_mid = cumulative + c_weight + next_c.weight / 2.0;

        if target <= mid && i > 0 {
            // Target is before mid_i; go back one centroid
            let prev_cumulative = if i <= 1 {
                0.0
            } else {
                self.fenwick_prefix_sum(i - 2)
            };
            let prev = &self.centroids[i - 1];
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
    }

    /// Returns the estimated CDF value (proportion <= x).
    ///
    /// Uses binary search on centroid means and the Fenwick tree for O(log n)
    /// cumulative weight lookups.
    pub fn cdf(&mut self, x: f64) -> Option<f64> {
        if !self.buffer.is_empty() {
            self.compress();
        }
        if self.centroids.is_empty() {
            return None;
        }
        if x <= self.min {
            return Some(0.0);
        }
        if x >= self.max {
            return Some(1.0);
        }

        let n = self.total_weight;
        let count = self.centroids.len();

        // Binary search: find the rightmost centroid with mean <= x.
        // partition_point returns the first index where mean > x.
        let pos = self.centroids.partition_point(|c| c.mean <= x);

        // x is less than the first centroid's mean
        if pos == 0 {
            let c_weight = self.centroids[0].weight;
            let c_mean = self.centroids[0].mean;
            let inner_w = c_weight / 2.0;
            let frac = if c_mean == self.min {
                1.0
            } else {
                (x - self.min) / (c_mean - self.min)
            };
            return Some((inner_w * frac) / n);
        }

        // i is the last centroid with mean <= x
        let i = pos - 1;
        let c_mean = self.centroids[i].mean;
        let c_weight = self.centroids[i].weight;
        let cumulative = if i == 0 {
            0.0
        } else {
            self.fenwick_prefix_sum(i - 1)
        };

        // x is beyond the last centroid's mean
        if i == count - 1 {
            let right_w = n - cumulative - c_weight / 2.0;
            let frac = if self.max == c_mean {
                0.0
            } else {
                (x - c_mean) / (self.max - c_mean)
            };
            return Some((cumulative + c_weight / 2.0 + right_w * frac) / n);
        }

        // x equals c_mean exactly (or is between c_mean and next centroid mean)
        let mid = cumulative + c_weight / 2.0;
        let next_c_mean = self.centroids[i + 1].mean;
        let next_c_weight = self.centroids[i + 1].weight;
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
        let mut other_clone = other.clone();
        if !other_clone.buffer.is_empty() {
            other_clone.compress();
        }
        for c in &other_clone.centroids {
            self.add(c.mean, c.weight);
        }
    }

    /// Returns the number of centroids after compressing.
    pub fn centroid_count(&mut self) -> usize {
        if !self.buffer.is_empty() {
            self.compress();
        }
        self.centroids.len()
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
