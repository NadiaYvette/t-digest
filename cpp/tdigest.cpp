/*
 * Dunning t-digest for online quantile estimation.
 * Merging digest variant with K_1 (arcsine) scale function.
 * Uses an array-backed 2-3-4 tree with monoidal measures.
 */

#include "tdigest.hpp"

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

static constexpr int BUFFER_FACTOR = 5;

static double weight_of(const TdMeasure &m) { return m.weight; }

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
  if (buffer_.empty() && tree_.size() <= 1)
    return;

  // Collect all centroids from tree and buffer
  std::vector<Centroid> all;
  all.reserve(tree_.size() + buffer_.size());
  tree_.collect(all);
  all.insert(all.end(), buffer_.begin(), buffer_.end());
  buffer_.clear();

  std::sort(all.begin(), all.end(), [](const Centroid &a, const Centroid &b) {
    return a.mean < b.mean;
  });

  // Merge centroids according to K1 scale function
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

  // Rebuild tree from sorted merged centroids
  tree_.build_from_sorted(merged);
}

double TDigest::quantile(double q) {
  if (!buffer_.empty())
    compress();

  if (tree_.size() == 0)
    return std::numeric_limits<double>::quiet_NaN();
  if (tree_.size() == 1) {
    // Single centroid - collect and return its mean
    std::vector<Centroid> all;
    tree_.collect(all);
    return all[0].mean;
  }

  if (q < 0.0)
    q = 0.0;
  if (q > 1.0)
    q = 1.0;

  // Collect centroids for interpolation (same logic as before)
  std::vector<Centroid> centroids;
  tree_.collect(centroids);
  size_t sz = centroids.size();

  double n = total_weight_;
  double target = q * n;

  // Build prefix sums for cumulative weights
  std::vector<double> cum(sz);
  cum[0] = centroids[0].weight;
  for (size_t i = 1; i < sz; i++)
    cum[i] = cum[i - 1] + centroids[i].weight;

  // Handle first centroid edge case
  const auto &first = centroids[0];
  if (target < first.weight / 2.0) {
    if (first.weight == 1.0)
      return min_;
    return min_ + (first.mean - min_) * (target / (first.weight / 2.0));
  }

  // Handle last centroid edge case
  const auto &last = centroids[sz - 1];
  if (target > n - last.weight / 2.0) {
    if (last.weight == 1.0)
      return max_;
    double remaining = n - last.weight / 2.0;
    return last.mean +
           (max_ - last.mean) * ((target - remaining) / (last.weight / 2.0));
  }

  // Find the centroid whose cumulative weight range contains target
  // Use binary search on cumulative weights
  int idx = 0;
  {
    int lo = 0, hi = static_cast<int>(sz) - 1;
    while (lo < hi) {
      int mid = (lo + hi) / 2;
      if (cum[mid] < target)
        lo = mid + 1;
      else
        hi = mid;
    }
    idx = lo;
  }

  if (idx >= static_cast<int>(sz) - 1)
    idx = static_cast<int>(sz) - 2;
  if (idx < 0)
    idx = 0;

  double cumulative = (idx > 0) ? cum[idx - 1] : 0.0;
  const auto &c = centroids[idx];
  double mid_val = cumulative + c.weight / 2.0;

  if (idx > 0 && target < mid_val) {
    idx--;
    cumulative = (idx > 0) ? cum[idx - 1] : 0.0;
    const auto &c2 = centroids[idx];
    double mid2 = cumulative + c2.weight / 2.0;
    const auto &next_c = centroids[idx + 1];
    double next_mid = cumulative + c2.weight + next_c.weight / 2.0;
    double frac =
        (next_mid == mid2) ? 0.5 : (target - mid2) / (next_mid - mid2);
    return c2.mean + frac * (next_c.mean - c2.mean);
  }

  if (static_cast<size_t>(idx) == sz - 1)
    return c.mean;

  const auto &next_c = centroids[idx + 1];
  double next_mid = cumulative + c.weight + next_c.weight / 2.0;

  if (target <= next_mid) {
    double frac =
        (next_mid == mid_val) ? 0.5 : (target - mid_val) / (next_mid - mid_val);
    return c.mean + frac * (next_c.mean - c.mean);
  }

  return max_;
}

double TDigest::cdf(double x) {
  if (!buffer_.empty())
    compress();

  if (tree_.size() == 0)
    return std::numeric_limits<double>::quiet_NaN();
  if (x <= min_)
    return 0.0;
  if (x >= max_)
    return 1.0;

  // Collect centroids for interpolation
  std::vector<Centroid> centroids;
  tree_.collect(centroids);
  size_t sz = centroids.size();
  double n = total_weight_;

  // Build prefix sums
  std::vector<double> cum(sz);
  cum[0] = centroids[0].weight;
  for (size_t i = 1; i < sz; i++)
    cum[i] = cum[i - 1] + centroids[i].weight;

  // Binary search for position
  auto it = std::lower_bound(
      centroids.begin(), centroids.end(), x,
      [](const Centroid &c, double val) { return c.mean < val; });

  size_t pos = static_cast<size_t>(it - centroids.begin());

  // x is less than the first centroid's mean
  if (pos == 0) {
    const auto &c = centroids[0];
    if (x < c.mean) {
      double inner_w = c.weight / 2.0;
      double frac = (c.mean == min_) ? 1.0 : (x - min_) / (c.mean - min_);
      return (inner_w * frac) / n;
    }
    return (c.weight / 2.0) / n;
  }

  // x is >= all centroid means
  if (pos == sz) {
    const auto &c = centroids[sz - 1];
    double cumulative =
        (sz > 1) ? cum[sz - 2] : 0.0;
    if (x > c.mean) {
      double right_w = n - cumulative - c.weight / 2.0;
      double frac = (max_ == c.mean) ? 0.0 : (x - c.mean) / (max_ - c.mean);
      return (cumulative + c.weight / 2.0 + right_w * frac) / n;
    }
    return (cumulative + c.weight / 2.0) / n;
  }

  // x is between centroids_[pos-1].mean and centroids_[pos].mean
  size_t i = pos - 1;
  const auto &c = centroids[i];
  const auto &next_c = centroids[pos];

  double cumulative = (i > 0) ? cum[i - 1] : 0.0;
  double mid_cdf = cumulative + c.weight / 2.0;
  double next_cumulative = cumulative + c.weight;
  double next_mid = next_cumulative + next_c.weight / 2.0;

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

  return next_mid / n;
}

void TDigest::merge(const TDigest &other) {
  std::vector<Centroid> other_centroids;
  other.tree_.collect(other_centroids);
  for (const auto &c : other_centroids) {
    add(c.mean, c.weight);
  }
  for (const auto &c : other.buffer_) {
    add(c.mean, c.weight);
  }
}

int TDigest::centroidCount() {
  if (!buffer_.empty())
    compress();
  return tree_.size();
}

double TDigest::totalWeight() const { return total_weight_; }
