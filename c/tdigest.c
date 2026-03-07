/*
 * Dunning t-digest for online quantile estimation.
 * Merging digest variant with K_1 (arcsine) scale function.
 * Uses an array-backed 2-3-4 tree with four-component monoidal measures.
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

/* ------------------------------------------------------------------ */
/*  Centroid                                                           */
/* ------------------------------------------------------------------ */

typedef struct {
  double mean;
  double weight;
} centroid_t;

/* ------------------------------------------------------------------ */
/*  TdMeasure – four-component monoidal annotation                     */
/* ------------------------------------------------------------------ */

typedef struct {
  double weight;          /* total weight in subtree   */
  int count;              /* number of centroids       */
  double max_mean;        /* max mean in subtree       */
  double mean_weight_sum; /* sum(mean * weight)        */
} td_measure_t;

static td_measure_t td_measure_identity(void) {
  td_measure_t m;
  m.weight = 0.0;
  m.count = 0;
  m.max_mean = -INFINITY;
  m.mean_weight_sum = 0.0;
  return m;
}

static td_measure_t td_measure_of(const centroid_t *c) {
  td_measure_t m;
  m.weight = c->weight;
  m.count = 1;
  m.max_mean = c->mean;
  m.mean_weight_sum = c->mean * c->weight;
  return m;
}

static td_measure_t td_measure_combine(td_measure_t a, td_measure_t b) {
  td_measure_t m;
  m.weight = a.weight + b.weight;
  m.count = a.count + b.count;
  m.max_mean = (a.max_mean > b.max_mean) ? a.max_mean : b.max_mean;
  m.mean_weight_sum = a.mean_weight_sum + b.mean_weight_sum;
  return m;
}

/* ------------------------------------------------------------------ */
/*  Array-backed 2-3-4 tree node                                       */
/* ------------------------------------------------------------------ */

typedef struct {
  int n;              /* 1..3 keys */
  centroid_t keys[3];
  int children[4];    /* -1 = no child (leaf edge) */
  td_measure_t measure;
} td_node_t;

/* ------------------------------------------------------------------ */
/*  Tree234 – array-backed with free list                              */
/* ------------------------------------------------------------------ */

typedef struct {
  td_node_t *nodes;
  int node_count;
  int node_cap;

  int *free_list;
  int free_count;
  int free_cap;

  int root;
  int size; /* number of keys */
} tree234_t;

static void tree234_init(tree234_t *t) {
  t->nodes = NULL;
  t->node_count = 0;
  t->node_cap = 0;
  t->free_list = NULL;
  t->free_count = 0;
  t->free_cap = 0;
  t->root = -1;
  t->size = 0;
}

static void tree234_destroy(tree234_t *t) {
  free(t->nodes);
  free(t->free_list);
  t->nodes = NULL;
  t->free_list = NULL;
  t->node_count = 0;
  t->node_cap = 0;
  t->free_count = 0;
  t->free_cap = 0;
  t->root = -1;
  t->size = 0;
}

static void tree234_clear(tree234_t *t) {
  t->node_count = 0;
  t->free_count = 0;
  t->root = -1;
  t->size = 0;
}

static void node_init(td_node_t *nd) {
  nd->n = 0;
  nd->children[0] = nd->children[1] = nd->children[2] = nd->children[3] = -1;
  nd->measure = td_measure_identity();
}

static int tree234_alloc(tree234_t *t) {
  int idx;
  if (t->free_count > 0) {
    idx = t->free_list[--t->free_count];
    node_init(&t->nodes[idx]);
    return idx;
  }
  if (t->node_count >= t->node_cap) {
    int new_cap = (t->node_cap == 0) ? 64 : t->node_cap * 2;
    t->nodes = (td_node_t *)realloc(t->nodes, new_cap * sizeof(td_node_t));
    t->node_cap = new_cap;
  }
  idx = t->node_count++;
  node_init(&t->nodes[idx]);
  return idx;
}

static void tree234_free_node(tree234_t *t, int idx) {
  if (t->free_count >= t->free_cap) {
    int new_cap = (t->free_cap == 0) ? 64 : t->free_cap * 2;
    t->free_list = (int *)realloc(t->free_list, new_cap * sizeof(int));
    t->free_cap = new_cap;
  }
  t->free_list[t->free_count++] = idx;
}

/* ------------------------------------------------------------------ */
/*  Measure recomputation                                              */
/* ------------------------------------------------------------------ */

static void recompute_measure(tree234_t *t, int idx) {
  td_node_t *nd = &t->nodes[idx];
  td_measure_t m = td_measure_identity();
  for (int i = 0; i <= nd->n; i++) {
    if (nd->children[i] != -1)
      m = td_measure_combine(m, t->nodes[nd->children[i]].measure);
    if (i < nd->n)
      m = td_measure_combine(m, td_measure_of(&nd->keys[i]));
  }
  nd->measure = m;
}

/* ------------------------------------------------------------------ */
/*  Top-down split of a 4-node child                                   */
/* ------------------------------------------------------------------ */

static void split_child(tree234_t *t, int parent_idx, int child_pos) {
  int child_idx = t->nodes[parent_idx].children[child_pos];

  /* Save child data before alloc (may realloc) */
  centroid_t k0 = t->nodes[child_idx].keys[0];
  centroid_t k1 = t->nodes[child_idx].keys[1];
  centroid_t k2 = t->nodes[child_idx].keys[2];
  int c0 = t->nodes[child_idx].children[0];
  int c1 = t->nodes[child_idx].children[1];
  int c2 = t->nodes[child_idx].children[2];
  int c3 = t->nodes[child_idx].children[3];

  int right_idx = tree234_alloc(t);
  /* pointers may have moved; access by index */

  t->nodes[right_idx].n = 1;
  t->nodes[right_idx].keys[0] = k2;
  t->nodes[right_idx].children[0] = c2;
  t->nodes[right_idx].children[1] = c3;

  /* Shrink child to left half */
  t->nodes[child_idx].n = 1;
  t->nodes[child_idx].keys[0] = k0;
  t->nodes[child_idx].children[0] = c0;
  t->nodes[child_idx].children[1] = c1;
  t->nodes[child_idx].children[2] = -1;
  t->nodes[child_idx].children[3] = -1;

  recompute_measure(t, child_idx);
  recompute_measure(t, right_idx);

  /* Insert mid key (k1) into parent at child_pos */
  td_node_t *p = &t->nodes[parent_idx];
  for (int i = p->n; i > child_pos; i--) {
    p->keys[i] = p->keys[i - 1];
    p->children[i + 1] = p->children[i];
  }
  p->keys[child_pos] = k1;
  p->children[child_pos + 1] = right_idx;
  p->n++;

  recompute_measure(t, parent_idx);
}

/* ------------------------------------------------------------------ */
/*  Insert into a non-full node                                        */
/* ------------------------------------------------------------------ */

static int centroid_compare(const centroid_t *a, const centroid_t *b) {
  if (a->mean < b->mean) return -1;
  if (a->mean > b->mean) return 1;
  return 0;
}

static void insert_non_full(tree234_t *t, int idx, const centroid_t *key) {
  td_node_t *nd = &t->nodes[idx];
  if (nd->children[0] == -1) {
    /* Leaf: insert in sorted position */
    int pos = nd->n;
    while (pos > 0 && centroid_compare(key, &nd->keys[pos - 1]) < 0) {
      nd->keys[pos] = nd->keys[pos - 1];
      pos--;
    }
    nd->keys[pos] = *key;
    nd->n++;
    recompute_measure(t, idx);
    return;
  }

  /* Find child to descend into */
  int pos = 0;
  while (pos < nd->n && centroid_compare(key, &nd->keys[pos]) >= 0)
    pos++;

  if (t->nodes[t->nodes[idx].children[pos]].n == 3) {
    split_child(t, idx, pos);
    if (centroid_compare(key, &t->nodes[idx].keys[pos]) >= 0)
      pos++;
  }

  insert_non_full(t, t->nodes[idx].children[pos], key);
  recompute_measure(t, idx);
}

static void tree234_insert(tree234_t *t, const centroid_t *key) {
  if (t->root == -1) {
    t->root = tree234_alloc(t);
    t->nodes[t->root].n = 1;
    t->nodes[t->root].keys[0] = *key;
    recompute_measure(t, t->root);
    t->size++;
    return;
  }

  if (t->nodes[t->root].n == 3) {
    int old_root = t->root;
    t->root = tree234_alloc(t);
    t->nodes[t->root].children[0] = old_root;
    split_child(t, t->root, 0);
  }

  insert_non_full(t, t->root, key);
  t->size++;
}

/* ------------------------------------------------------------------ */
/*  In-order collect                                                   */
/* ------------------------------------------------------------------ */

static void collect_impl(const tree234_t *t, int idx,
                          centroid_t *out, int *pos) {
  if (idx == -1)
    return;
  const td_node_t *nd = &t->nodes[idx];
  for (int i = 0; i <= nd->n; i++) {
    if (nd->children[i] != -1)
      collect_impl(t, nd->children[i], out, pos);
    if (i < nd->n)
      out[(*pos)++] = nd->keys[i];
  }
}

/* Collect all centroids in-order into caller-provided array.
   Array must have space for at least t->size elements. */
static void tree234_collect(const tree234_t *t, centroid_t *out) {
  int pos = 0;
  collect_impl(t, t->root, out, &pos);
}

/* ------------------------------------------------------------------ */
/*  Build balanced tree from sorted array                              */
/* ------------------------------------------------------------------ */

static int build_recursive(tree234_t *t, const centroid_t *sorted,
                            int lo, int hi) {
  int n = hi - lo;
  if (n <= 0) return -1;

  if (n <= 3) {
    int idx = tree234_alloc(t);
    t->nodes[idx].n = n;
    for (int i = 0; i < n; i++)
      t->nodes[idx].keys[i] = sorted[lo + i];
    recompute_measure(t, idx);
    return idx;
  }

  if (n <= 7) {
    int mid = lo + n / 2;
    int left = build_recursive(t, sorted, lo, mid);
    int right = build_recursive(t, sorted, mid + 1, hi);
    int idx = tree234_alloc(t);
    t->nodes[idx].n = 1;
    t->nodes[idx].keys[0] = sorted[mid];
    t->nodes[idx].children[0] = left;
    t->nodes[idx].children[1] = right;
    recompute_measure(t, idx);
    return idx;
  }

  /* Use 3-node (2 keys) to keep tree balanced */
  int third = n / 3;
  int m1 = lo + third;
  int m2 = lo + 2 * third + 1;
  int c0 = build_recursive(t, sorted, lo, m1);
  int c1 = build_recursive(t, sorted, m1 + 1, m2);
  int c2 = build_recursive(t, sorted, m2 + 1, hi);
  int idx = tree234_alloc(t);
  t->nodes[idx].n = 2;
  t->nodes[idx].keys[0] = sorted[m1];
  t->nodes[idx].keys[1] = sorted[m2];
  t->nodes[idx].children[0] = c0;
  t->nodes[idx].children[1] = c1;
  t->nodes[idx].children[2] = c2;
  recompute_measure(t, idx);
  return idx;
}

static void tree234_build_from_sorted(tree234_t *t, const centroid_t *sorted,
                                       int count) {
  tree234_clear(t);
  if (count <= 0) return;
  t->size = count;
  t->root = build_recursive(t, sorted, 0, count);
}

/* ------------------------------------------------------------------ */
/*  find_by_weight – walk tree using subtree measures                   */
/* ------------------------------------------------------------------ */

typedef struct {
  centroid_t key;
  double cum_before;
  int index;
  int found;
} weight_result_t;

static int subtree_count(const tree234_t *t, int idx) {
  if (idx == -1) return 0;
  return t->nodes[idx].measure.count;
}

static weight_result_t find_by_weight_impl(const tree234_t *t, int idx,
                                            double target, double cum,
                                            int global_idx) {
  weight_result_t fail = {{0, 0}, 0, 0, 0};
  if (idx == -1) return fail;

  const td_node_t *nd = &t->nodes[idx];
  double running_cum = cum;
  int running_idx = global_idx;

  for (int i = 0; i <= nd->n; i++) {
    if (nd->children[i] != -1) {
      double child_w = t->nodes[nd->children[i]].measure.weight;
      if (running_cum + child_w >= target) {
        return find_by_weight_impl(t, nd->children[i], target,
                                    running_cum, running_idx);
      }
      running_cum += child_w;
      running_idx += subtree_count(t, nd->children[i]);
    }
    if (i < nd->n) {
      double key_w = nd->keys[i].weight;
      if (running_cum + key_w >= target) {
        weight_result_t r;
        r.key = nd->keys[i];
        r.cum_before = running_cum;
        r.index = running_idx;
        r.found = 1;
        return r;
      }
      running_cum += key_w;
      running_idx++;
    }
  }
  return fail;
}

/* ------------------------------------------------------------------ */
/*  tdigest struct                                                     */
/* ------------------------------------------------------------------ */

struct tdigest {
  double delta;
  double total_weight;
  double min;
  double max;

  tree234_t tree;

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
  if (ma < mb) return -1;
  if (ma > mb) return 1;
  return 0;
}

/* ------------------------------------------------------------------ */
/*  Public API                                                         */
/* ------------------------------------------------------------------ */

tdigest_t *tdigest_new(double delta) {
  tdigest_t *td = (tdigest_t *)calloc(1, sizeof(tdigest_t));
  if (!td) return NULL;

  td->delta = delta;
  td->total_weight = 0.0;
  td->min = INFINITY;
  td->max = -INFINITY;

  tree234_init(&td->tree);

  td->buffer_count = 0;
  td->buffer_cap = (int)ceil(delta * BUFFER_FACTOR);
  td->buffer = (centroid_t *)malloc(td->buffer_cap * sizeof(centroid_t));

  return td;
}

void tdigest_free(tdigest_t *td) {
  if (!td) return;
  tree234_destroy(&td->tree);
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
  if (value < td->min) td->min = value;
  if (value > td->max) td->max = value;
}

void tdigest_compress(tdigest_t *td) {
  if (td->buffer_count == 0 && td->tree.size <= 1)
    return;

  int tree_count = td->tree.size;
  int all_count = tree_count + td->buffer_count;
  centroid_t *all = (centroid_t *)malloc(all_count * sizeof(centroid_t));

  /* Collect from tree */
  if (tree_count > 0)
    tree234_collect(&td->tree, all);

  /* Append buffer */
  memcpy(all + tree_count, td->buffer,
         td->buffer_count * sizeof(centroid_t));
  td->buffer_count = 0;

  qsort(all, all_count, sizeof(centroid_t), centroid_cmp);

  /* Merge centroids according to K1 scale function */
  centroid_t *merged = (centroid_t *)malloc(all_count * sizeof(centroid_t));
  merged[0] = all[0];
  int new_count = 1;
  double weight_so_far = 0.0;
  double n = td->total_weight;

  for (int i = 1; i < all_count; i++) {
    double proposed = merged[new_count - 1].weight + all[i].weight;
    double q0 = weight_so_far / n;
    double q1 = (weight_so_far + proposed) / n;

    if ((proposed <= 1.0 && all_count > 1) ||
        (k_scale(q1, td->delta) - k_scale(q0, td->delta) <= 1.0)) {
      /* Merge into last centroid */
      centroid_t *last = &merged[new_count - 1];
      double new_weight = last->weight + all[i].weight;
      last->mean = (last->mean * last->weight + all[i].mean * all[i].weight) /
                   new_weight;
      last->weight = new_weight;
    } else {
      weight_so_far += merged[new_count - 1].weight;
      merged[new_count] = all[i];
      new_count++;
    }
  }

  /* Rebuild tree from sorted merged centroids */
  tree234_build_from_sorted(&td->tree, merged, new_count);

  free(all);
  free(merged);
}

double tdigest_quantile(tdigest_t *td, double q) {
  if (td->buffer_count > 0)
    tdigest_compress(td);

  int sz = td->tree.size;
  if (sz == 0) return NAN;
  if (sz == 1) {
    centroid_t c;
    tree234_collect(&td->tree, &c);
    return c.mean;
  }

  if (q < 0.0) q = 0.0;
  if (q > 1.0) q = 1.0;

  /* Collect centroids for interpolation */
  centroid_t *centroids = (centroid_t *)malloc(sz * sizeof(centroid_t));
  tree234_collect(&td->tree, centroids);

  double n = td->total_weight;
  double target = q * n;
  double cumulative = 0.0;
  double result = td->max;

  for (int i = 0; i < sz; i++) {
    centroid_t *c = &centroids[i];
    double mid = cumulative + c->weight / 2.0;

    if (i == 0) {
      if (target < c->weight / 2.0) {
        if (c->weight == 1.0) { result = td->min; goto done; }
        result = td->min + (c->mean - td->min) * (target / (c->weight / 2.0));
        goto done;
      }
    }

    if (i == sz - 1) {
      if (target > n - c->weight / 2.0) {
        if (c->weight == 1.0) { result = td->max; goto done; }
        double remaining = n - c->weight / 2.0;
        result = c->mean +
                 (td->max - c->mean) * ((target - remaining) / (c->weight / 2.0));
        goto done;
      }
      result = c->mean;
      goto done;
    }

    centroid_t *next_c = &centroids[i + 1];
    double next_mid = cumulative + c->weight + next_c->weight / 2.0;

    if (target <= next_mid) {
      double frac = (next_mid == mid) ? 0.5 : (target - mid) / (next_mid - mid);
      result = c->mean + frac * (next_c->mean - c->mean);
      goto done;
    }

    cumulative += c->weight;
  }

done:
  free(centroids);
  return result;
}

double tdigest_cdf(tdigest_t *td, double x) {
  if (td->buffer_count > 0)
    tdigest_compress(td);

  int sz = td->tree.size;
  if (sz == 0) return NAN;
  if (x <= td->min) return 0.0;
  if (x >= td->max) return 1.0;

  centroid_t *centroids = (centroid_t *)malloc(sz * sizeof(centroid_t));
  tree234_collect(&td->tree, centroids);

  double n = td->total_weight;
  double cumulative = 0.0;
  double result = 1.0;

  for (int i = 0; i < sz; i++) {
    centroid_t *c = &centroids[i];

    if (i == 0) {
      if (x < c->mean) {
        double inner_w = c->weight / 2.0;
        double frac =
            (c->mean == td->min) ? 1.0 : (x - td->min) / (c->mean - td->min);
        result = (inner_w * frac) / n;
        goto done;
      } else if (x == c->mean) {
        result = (c->weight / 2.0) / n;
        goto done;
      }
    }

    if (i == sz - 1) {
      if (x > c->mean) {
        double right_w = n - cumulative - c->weight / 2.0;
        double frac =
            (td->max == c->mean) ? 0.0 : (x - c->mean) / (td->max - c->mean);
        result = (cumulative + c->weight / 2.0 + right_w * frac) / n;
      } else {
        result = (cumulative + c->weight / 2.0) / n;
      }
      goto done;
    }

    double mid_cdf = cumulative + c->weight / 2.0;
    centroid_t *next_c = &centroids[i + 1];
    double next_cumulative = cumulative + c->weight;
    double next_mid = next_cumulative + next_c->weight / 2.0;

    if (x < next_c->mean) {
      if (c->mean == next_c->mean) {
        result = (mid_cdf + (next_mid - mid_cdf) / 2.0) / n;
      } else {
        double frac = (x - c->mean) / (next_c->mean - c->mean);
        result = (mid_cdf + frac * (next_mid - mid_cdf)) / n;
      }
      goto done;
    }

    cumulative += c->weight;
  }

done:
  free(centroids);
  return result;
}

void tdigest_merge(tdigest_t *td, const tdigest_t *other) {
  /* Add all centroids from other's tree */
  if (other->tree.size > 0) {
    centroid_t *others = (centroid_t *)malloc(other->tree.size * sizeof(centroid_t));
    tree234_collect(&other->tree, others);
    for (int i = 0; i < other->tree.size; i++) {
      tdigest_add(td, others[i].mean, others[i].weight);
    }
    free(others);
  }
  /* Add buffer entries */
  for (int i = 0; i < other->buffer_count; i++) {
    tdigest_add(td, other->buffer[i].mean, other->buffer[i].weight);
  }
}

int tdigest_centroid_count(tdigest_t *td) {
  if (td->buffer_count > 0)
    tdigest_compress(td);
  return td->tree.size;
}

double tdigest_total_weight(const tdigest_t *td) { return td->total_weight; }
