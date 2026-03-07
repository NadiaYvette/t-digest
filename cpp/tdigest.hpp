/*
 * Dunning t-digest for online quantile estimation.
 * Merging digest variant with K_1 (arcsine) scale function.
 * Uses an array-backed 2-3-4 tree with monoidal measures.
 *
 * k(q, delta) = (delta / (2*pi)) * asin(2*q - 1)
 */

#ifndef TDIGEST_HPP
#define TDIGEST_HPP

#include <algorithm>
#include <cmath>
#include <limits>
#include <vector>

#include "tree234.hpp"

struct Centroid {
  double mean;
  double weight;
  Centroid() : mean(0), weight(0) {}
  Centroid(double m, double w) : mean(m), weight(w) {}
};

struct TdMeasure {
  double weight = 0;
  int count = 0;
  double max_mean = -std::numeric_limits<double>::infinity();
  double mean_weight_sum = 0;
};

struct CentroidTraits {
  static TdMeasure measure(const Centroid &c) {
    return {c.weight, 1, c.mean, c.mean * c.weight};
  }
  static TdMeasure combine(const TdMeasure &a, const TdMeasure &b) {
    return {a.weight + b.weight, a.count + b.count, std::max(a.max_mean, b.max_mean),
            a.mean_weight_sum + b.mean_weight_sum};
  }
  static TdMeasure identity() {
    return {0, 0, -std::numeric_limits<double>::infinity(), 0};
  }
  static int compare(const Centroid &a, const Centroid &b) {
    if (a.mean < b.mean)
      return -1;
    if (a.mean > b.mean)
      return 1;
    return 0;
  }
};

class TDigest {
public:
  explicit TDigest(double delta = 100.0);

  void add(double value, double weight = 1.0);
  void compress();
  double quantile(double q);
  double cdf(double x);
  void merge(const TDigest &other);
  int centroidCount();
  double totalWeight() const;

private:
  double delta_;
  double total_weight_;
  double min_;
  double max_;
  int buffer_cap_;

  Tree234<Centroid, TdMeasure, CentroidTraits> tree_;
  std::vector<Centroid> buffer_;

  double k(double q) const;
  static void mergeIntoLast(std::vector<Centroid> &centroids,
                            const Centroid &c);
};

#endif /* TDIGEST_HPP */
