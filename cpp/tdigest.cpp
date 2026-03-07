/*
 * Dunning t-digest for online quantile estimation.
 * Merging digest variant with K_1 (arcsine) scale function.
 */

#include "tdigest.hpp"

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

static constexpr int BUFFER_FACTOR = 5;

TDigest::TDigest(double delta)
    : delta_(delta), total_weight_(0.0),
      min_(std::numeric_limits<double>::infinity()),
      max_(-std::numeric_limits<double>::infinity()),
      buffer_cap_(static_cast<int>(std::ceil(delta * BUFFER_FACTOR))) {}

double TDigest::k(double q) const {
  return (delta_ / (2.0 * M_PI)) * std::asin(2.0 * q - 1.0);
}

void TDigest::mergeIntoLast(std::vector<Centroid> &centroids,
                            const Centroid &c) {
  auto &last = centroids.back();
  double new_weight = last.weight + c.weight;
  last.mean = (last.mean * last.weight + c.mean * c.weight) / new_weight;
  last.weight = new_weight;
}

void TDigest::add(double value, double weight) {
  buffer_.emplace_back(value, weight);
  total_weight_ += weight;
  if (value < min_)
    min_ = value;
  if (value > max_)
    max_ = value;
  if (static_cast<int>(buffer_.size()) >= buffer_cap_) {
    compress();
  }
}

void TDigest::compress() {
  if (buffer_.empty() && centroids_.size() <= 1)
    return;

  std::vector<Centroid> all;
  all.reserve(centroids_.size() + buffer_.size());
  all.insert(all.end(), centroids_.begin(), centroids_.end());
  all.insert(all.end(), buffer_.begin(), buffer_.end());
  buffer_.clear();

  std::sort(all.begin(), all.end(), [](const Centroid &a, const Centroid &b) {
    return a.mean < b.mean;
  });

  std::vector<Centroid> merged;
  merged.reserve(all.size());
  merged.push_back(all[0]);

  double weight_so_far = 0.0;
  double n = total_weight_;

  for (size_t i = 1; i < all.size(); i++) {
    double proposed = merged.back().weight + all[i].weight;
    double q0 = weight_so_far / n;
    double q1 = (weight_so_far + proposed) / n;

    if ((proposed <= 1.0 && all.size() > 1) || (k(q1) - k(q0) <= 1.0)) {
      mergeIntoLast(merged, all[i]);
    } else {
      weight_so_far += merged.back().weight;
      merged.push_back(all[i]);
    }
  }

  centroids_ = std::move(merged);
  fenwick_build();
}

void TDigest::fenwick_build() {
  int n = static_cast<int>(centroids_.size());
  fenwick_.assign(n + 1, 0.0);
  for (int i = 0; i < n; i++) {
    int j = i + 1; // 1-indexed
    fenwick_[j] += centroids_[i].weight;
    int parent = j + (j & (-j));
    if (parent <= n)
      fenwick_[parent] += fenwick_[j];
  }
}

double TDigest::fenwick_prefix_sum(int i) const {
  // Sum of weights for centroids_[0..i] (inclusive), i is 0-based
  double s = 0.0;
  for (int j = i + 1; j > 0; j -= j & (-j))
    s += fenwick_[j];
  return s;
}

int TDigest::fenwick_find(double target) const {
  // Find smallest 0-based index i such that prefix_sum(i) >= target
  int n = static_cast<int>(centroids_.size());
  int pos = 0;
  double sum = 0.0;
  for (int bit = 1 << static_cast<int>(std::log2(n > 0 ? n : 1)); bit > 0;
       bit >>= 1) {
    if (pos + bit <= n && sum + fenwick_[pos + bit] < target) {
      pos += bit;
      sum += fenwick_[pos];
    }
  }
  return pos; // 0-based index
}

double TDigest::quantile(double q) {
  if (!buffer_.empty())
    compress();
  if (centroids_.empty())
    return std::numeric_limits<double>::quiet_NaN();
  if (centroids_.size() == 1)
    return centroids_[0].mean;

  if (q < 0.0)
    q = 0.0;
  if (q > 1.0)
    q = 1.0;

  double n = total_weight_;
  double target = q * n;
  size_t sz = centroids_.size();

  // Handle first centroid edge case
  const auto &first = centroids_[0];
  if (target < first.weight / 2.0) {
    if (first.weight == 1.0)
      return min_;
    return min_ + (first.mean - min_) * (target / (first.weight / 2.0));
  }

  // Handle last centroid edge case
  const auto &last = centroids_[sz - 1];
  if (target > n - last.weight / 2.0) {
    if (last.weight == 1.0)
      return max_;
    double remaining = n - last.weight / 2.0;
    return last.mean +
           (max_ - last.mean) * ((target - remaining) / (last.weight / 2.0));
  }

  // Use Fenwick tree to find the centroid whose cumulative weight range
  // contains the target. fenwick_find returns the first index where
  // prefix_sum >= target.
  int idx = fenwick_find(target);
  // Clamp to valid range for interpolation
  if (idx >= static_cast<int>(sz) - 1)
    idx = static_cast<int>(sz) - 2;
  if (idx < 0)
    idx = 0;

  // Compute cumulative weight up to (but not including) centroid[idx]
  double cumulative = (idx > 0) ? fenwick_prefix_sum(idx - 1) : 0.0;
  const auto &c = centroids_[idx];
  double mid = cumulative + c.weight / 2.0;

  // If target is before this centroid's midpoint, look at the previous pair
  if (idx > 0 && target < mid) {
    idx--;
    cumulative = (idx > 0) ? fenwick_prefix_sum(idx - 1) : 0.0;
    const auto &c2 = centroids_[idx];
    double mid2 = cumulative + c2.weight / 2.0;
    const auto &next_c = centroids_[idx + 1];
    double next_mid = cumulative + c2.weight + next_c.weight / 2.0;
    double frac =
        (next_mid == mid2) ? 0.5 : (target - mid2) / (next_mid - mid2);
    return c2.mean + frac * (next_c.mean - c2.mean);
  }

  if (static_cast<size_t>(idx) == sz - 1)
    return c.mean;

  const auto &next_c = centroids_[idx + 1];
  double next_mid = cumulative + c.weight + next_c.weight / 2.0;

  if (target <= next_mid) {
    double frac = (next_mid == mid) ? 0.5 : (target - mid) / (next_mid - mid);
    return c.mean + frac * (next_c.mean - c.mean);
  }

  return max_;
}

double TDigest::cdf(double x) {
  if (!buffer_.empty())
    compress();
  if (centroids_.empty())
    return std::numeric_limits<double>::quiet_NaN();
  if (x <= min_)
    return 0.0;
  if (x >= max_)
    return 1.0;

  double n = total_weight_;
  size_t sz = centroids_.size();

  // Use binary search (std::lower_bound) to find the first centroid with
  // mean >= x, giving O(log n) lookup by value.
  auto it = std::lower_bound(
      centroids_.begin(), centroids_.end(), x,
      [](const Centroid &c, double val) { return c.mean < val; });

  size_t pos = static_cast<size_t>(it - centroids_.begin());

  // x is less than the first centroid's mean
  if (pos == 0) {
    const auto &c = centroids_[0];
    if (x < c.mean) {
      double inner_w = c.weight / 2.0;
      double frac = (c.mean == min_) ? 1.0 : (x - min_) / (c.mean - min_);
      return (inner_w * frac) / n;
    }
    // x == c.mean
    return (c.weight / 2.0) / n;
  }

  // x is >= all centroid means
  if (pos == sz) {
    const auto &c = centroids_[sz - 1];
    double cumulative =
        (sz > 1) ? fenwick_prefix_sum(static_cast<int>(sz) - 2) : 0.0;
    if (x > c.mean) {
      double right_w = n - cumulative - c.weight / 2.0;
      double frac = (max_ == c.mean) ? 0.0 : (x - c.mean) / (max_ - c.mean);
      return (cumulative + c.weight / 2.0 + right_w * frac) / n;
    }
    return (cumulative + c.weight / 2.0) / n;
  }

  // x is between centroids_[pos-1].mean and centroids_[pos].mean
  // (or exactly at centroids_[pos].mean)
  size_t i = pos - 1;
  const auto &c = centroids_[i];
  const auto &next_c = centroids_[pos];

  double cumulative =
      (i > 0) ? fenwick_prefix_sum(static_cast<int>(i) - 1) : 0.0;
  double mid_cdf = cumulative + c.weight / 2.0;
  double next_cumulative = cumulative + c.weight;
  double next_mid = next_cumulative + next_c.weight / 2.0;

  // Check if this is the last centroid
  if (i == sz - 1) {
    if (x > c.mean) {
      double right_w = n - cumulative - c.weight / 2.0;
      double frac = (max_ == c.mean) ? 0.0 : (x - c.mean) / (max_ - c.mean);
      return (cumulative + c.weight / 2.0 + right_w * frac) / n;
    }
    return (cumulative + c.weight / 2.0) / n;
  }

  if (x < next_c.mean) {
    if (c.mean == next_c.mean) {
      return (mid_cdf + (next_mid - mid_cdf) / 2.0) / n;
    }
    double frac = (x - c.mean) / (next_c.mean - c.mean);
    return (mid_cdf + frac * (next_mid - mid_cdf)) / n;
  }

  // x == next_c.mean exactly
  return next_mid / n;
}

void TDigest::merge(const TDigest &other) {
  for (const auto &c : other.centroids_) {
    add(c.mean, c.weight);
  }
  for (const auto &c : other.buffer_) {
    add(c.mean, c.weight);
  }
}

int TDigest::centroidCount() {
  if (!buffer_.empty())
    compress();
  return static_cast<int>(centroids_.size());
}

double TDigest::totalWeight() const { return total_weight_; }
