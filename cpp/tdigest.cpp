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
  double cumulative = 0.0;

  for (size_t i = 0; i < centroids_.size(); i++) {
    const auto &c = centroids_[i];
    double mid = cumulative + c.weight / 2.0;

    if (i == 0) {
      if (target < c.weight / 2.0) {
        if (c.weight == 1.0)
          return min_;
        return min_ + (c.mean - min_) * (target / (c.weight / 2.0));
      }
    }

    if (i == centroids_.size() - 1) {
      if (target > n - c.weight / 2.0) {
        if (c.weight == 1.0)
          return max_;
        double remaining = n - c.weight / 2.0;
        return c.mean +
               (max_ - c.mean) * ((target - remaining) / (c.weight / 2.0));
      }
      return c.mean;
    }

    const auto &next_c = centroids_[i + 1];
    double next_mid = cumulative + c.weight + next_c.weight / 2.0;

    if (target <= next_mid) {
      double frac = (next_mid == mid) ? 0.5 : (target - mid) / (next_mid - mid);
      return c.mean + frac * (next_c.mean - c.mean);
    }

    cumulative += c.weight;
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
  double cumulative = 0.0;

  for (size_t i = 0; i < centroids_.size(); i++) {
    const auto &c = centroids_[i];

    if (i == 0) {
      if (x < c.mean) {
        double inner_w = c.weight / 2.0;
        double frac = (c.mean == min_) ? 1.0 : (x - min_) / (c.mean - min_);
        return (inner_w * frac) / n;
      } else if (x == c.mean) {
        return (c.weight / 2.0) / n;
      }
    }

    if (i == centroids_.size() - 1) {
      if (x > c.mean) {
        double right_w = n - cumulative - c.weight / 2.0;
        double frac = (max_ == c.mean) ? 0.0 : (x - c.mean) / (max_ - c.mean);
        return (cumulative + c.weight / 2.0 + right_w * frac) / n;
      } else {
        return (cumulative + c.weight / 2.0) / n;
      }
    }

    double mid_cdf = cumulative + c.weight / 2.0;
    const auto &next_c = centroids_[i + 1];
    double next_cumulative = cumulative + c.weight;
    double next_mid = next_cumulative + next_c.weight / 2.0;

    if (x < next_c.mean) {
      if (c.mean == next_c.mean) {
        return (mid_cdf + (next_mid - mid_cdf) / 2.0) / n;
      }
      double frac = (x - c.mean) / (next_c.mean - c.mean);
      return (mid_cdf + frac * (next_mid - mid_cdf)) / n;
    }

    cumulative += c.weight;
  }

  return 1.0;
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
