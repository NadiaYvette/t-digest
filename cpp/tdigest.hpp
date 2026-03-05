/*
 * Dunning t-digest for online quantile estimation.
 * Merging digest variant with K_1 (arcsine) scale function.
 *
 * k(q, delta) = (delta / (2*pi)) * asin(2*q - 1)
 */

#ifndef TDIGEST_HPP
#define TDIGEST_HPP

#include <algorithm>
#include <cmath>
#include <limits>
#include <vector>

class TDigest {
public:
  struct Centroid {
    double mean;
    double weight;
    Centroid(double m, double w) : mean(m), weight(w) {}
  };

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

  std::vector<Centroid> centroids_;
  std::vector<Centroid> buffer_;

  double k(double q) const;
  static void mergeIntoLast(std::vector<Centroid> &centroids,
                            const Centroid &c);
};

#endif /* TDIGEST_HPP */
