/*
 * Dunning t-digest for online quantile estimation.
 * Merging digest variant with K_1 (arcsine) scale function.
 *
 * k(q, delta) = (delta / (2*pi)) * asin(2*q - 1)
 */

#include "tdigest.h"
#include <float.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

#define BUFFER_FACTOR 5

typedef struct {
  double mean;
  double weight;
} centroid_t;

struct tdigest {
  double delta;
  double total_weight;
  double min;
  double max;

  centroid_t *centroids;
  int centroid_count;
  int centroid_cap;

  centroid_t *buffer;
  int buffer_count;
  int buffer_cap;
};

/* K_1 scale function */
static double k_scale(double q, double delta) {
  return (delta / (2.0 * M_PI)) * asin(2.0 * q - 1.0);
}

static int centroid_cmp(const void *a, const void *b) {
  double ma = ((const centroid_t *)a)->mean;
  double mb = ((const centroid_t *)b)->mean;
  if (ma < mb)
    return -1;
  if (ma > mb)
    return 1;
  return 0;
}

tdigest_t *tdigest_new(double delta) {
  tdigest_t *td = (tdigest_t *)calloc(1, sizeof(tdigest_t));
  if (!td)
    return NULL;

  td->delta = delta;
  td->total_weight = 0.0;
  td->min = INFINITY;
  td->max = -INFINITY;

  td->centroid_count = 0;
  td->centroid_cap = 64;
  td->centroids = (centroid_t *)malloc(td->centroid_cap * sizeof(centroid_t));

  td->buffer_count = 0;
  td->buffer_cap = (int)ceil(delta * BUFFER_FACTOR);
  td->buffer = (centroid_t *)malloc(td->buffer_cap * sizeof(centroid_t));

  return td;
}

void tdigest_free(tdigest_t *td) {
  if (!td)
    return;
  free(td->centroids);
  free(td->buffer);
  free(td);
}

void tdigest_add(tdigest_t *td, double value, double weight) {
  if (td->buffer_count >= td->buffer_cap) {
    tdigest_compress(td);
  }
  td->buffer[td->buffer_count].mean = value;
  td->buffer[td->buffer_count].weight = weight;
  td->buffer_count++;
  td->total_weight += weight;
  if (value < td->min)
    td->min = value;
  if (value > td->max)
    td->max = value;
}

void tdigest_compress(tdigest_t *td) {
  if (td->buffer_count == 0 && td->centroid_count <= 1)
    return;

  int all_count = td->centroid_count + td->buffer_count;
  centroid_t *all = (centroid_t *)malloc(all_count * sizeof(centroid_t));
  memcpy(all, td->centroids, td->centroid_count * sizeof(centroid_t));
  memcpy(all + td->centroid_count, td->buffer,
         td->buffer_count * sizeof(centroid_t));
  td->buffer_count = 0;

  qsort(all, all_count, sizeof(centroid_t), centroid_cmp);

  /* Ensure capacity for new centroids */
  if (td->centroid_cap < all_count) {
    td->centroid_cap = all_count;
    td->centroids = (centroid_t *)realloc(
        td->centroids, td->centroid_cap * sizeof(centroid_t));
  }

  td->centroids[0] = all[0];
  int new_count = 1;
  double weight_so_far = 0.0;
  double n = td->total_weight;

  for (int i = 1; i < all_count; i++) {
    double proposed = td->centroids[new_count - 1].weight + all[i].weight;
    double q0 = weight_so_far / n;
    double q1 = (weight_so_far + proposed) / n;

    if ((proposed <= 1.0 && all_count > 1) ||
        (k_scale(q1, td->delta) - k_scale(q0, td->delta) <= 1.0)) {
      /* Merge into last centroid */
      centroid_t *last = &td->centroids[new_count - 1];
      double new_weight = last->weight + all[i].weight;
      last->mean = (last->mean * last->weight + all[i].mean * all[i].weight) /
                   new_weight;
      last->weight = new_weight;
    } else {
      weight_so_far += td->centroids[new_count - 1].weight;
      td->centroids[new_count] = all[i];
      new_count++;
    }
  }

  td->centroid_count = new_count;
  free(all);
}

double tdigest_quantile(tdigest_t *td, double q) {
  if (td->buffer_count > 0)
    tdigest_compress(td);
  if (td->centroid_count == 0)
    return NAN;
  if (td->centroid_count == 1)
    return td->centroids[0].mean;

  if (q < 0.0)
    q = 0.0;
  if (q > 1.0)
    q = 1.0;

  double n = td->total_weight;
  double target = q * n;
  double cumulative = 0.0;

  for (int i = 0; i < td->centroid_count; i++) {
    centroid_t *c = &td->centroids[i];
    double mid = cumulative + c->weight / 2.0;

    if (i == 0) {
      if (target < c->weight / 2.0) {
        if (c->weight == 1.0)
          return td->min;
        return td->min + (c->mean - td->min) * (target / (c->weight / 2.0));
      }
    }

    if (i == td->centroid_count - 1) {
      if (target > n - c->weight / 2.0) {
        if (c->weight == 1.0)
          return td->max;
        double remaining = n - c->weight / 2.0;
        return c->mean +
               (td->max - c->mean) * ((target - remaining) / (c->weight / 2.0));
      }
      return c->mean;
    }

    centroid_t *next_c = &td->centroids[i + 1];
    double next_mid = cumulative + c->weight + next_c->weight / 2.0;

    if (target <= next_mid) {
      double frac = (next_mid == mid) ? 0.5 : (target - mid) / (next_mid - mid);
      return c->mean + frac * (next_c->mean - c->mean);
    }

    cumulative += c->weight;
  }

  return td->max;
}

double tdigest_cdf(tdigest_t *td, double x) {
  if (td->buffer_count > 0)
    tdigest_compress(td);
  if (td->centroid_count == 0)
    return NAN;
  if (x <= td->min)
    return 0.0;
  if (x >= td->max)
    return 1.0;

  double n = td->total_weight;
  double cumulative = 0.0;

  for (int i = 0; i < td->centroid_count; i++) {
    centroid_t *c = &td->centroids[i];

    if (i == 0) {
      if (x < c->mean) {
        double inner_w = c->weight / 2.0;
        double frac =
            (c->mean == td->min) ? 1.0 : (x - td->min) / (c->mean - td->min);
        return (inner_w * frac) / n;
      } else if (x == c->mean) {
        return (c->weight / 2.0) / n;
      }
    }

    if (i == td->centroid_count - 1) {
      if (x > c->mean) {
        double right_w = n - cumulative - c->weight / 2.0;
        double frac =
            (td->max == c->mean) ? 0.0 : (x - c->mean) / (td->max - c->mean);
        return (cumulative + c->weight / 2.0 + right_w * frac) / n;
      } else {
        return (cumulative + c->weight / 2.0) / n;
      }
    }

    double mid_cdf = cumulative + c->weight / 2.0;
    centroid_t *next_c = &td->centroids[i + 1];
    double next_cumulative = cumulative + c->weight;
    double next_mid = next_cumulative + next_c->weight / 2.0;

    if (x < next_c->mean) {
      if (c->mean == next_c->mean) {
        return (mid_cdf + (next_mid - mid_cdf) / 2.0) / n;
      }
      double frac = (x - c->mean) / (next_c->mean - c->mean);
      return (mid_cdf + frac * (next_mid - mid_cdf)) / n;
    }

    cumulative += c->weight;
  }

  return 1.0;
}

void tdigest_merge(tdigest_t *td, const tdigest_t *other) {
  /* Compress other if needed by working with its centroids and buffer */
  /* We add all centroids and buffer entries from other */
  for (int i = 0; i < other->centroid_count; i++) {
    tdigest_add(td, other->centroids[i].mean, other->centroids[i].weight);
  }
  for (int i = 0; i < other->buffer_count; i++) {
    tdigest_add(td, other->buffer[i].mean, other->buffer[i].weight);
  }
}

int tdigest_centroid_count(tdigest_t *td) {
  if (td->buffer_count > 0)
    tdigest_compress(td);
  return td->centroid_count;
}

double tdigest_total_weight(const tdigest_t *td) { return td->total_weight; }
