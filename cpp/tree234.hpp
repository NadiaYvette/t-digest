#pragma once

/*
 * Generic array-backed 2-3-4 tree with monoidal measures.
 *
 * Template parameters:
 *   K      - key/element type (stored in sorted order)
 *   M      - measure type (monoidal annotation on subtrees)
 *   Traits - a struct providing:
 *       static M measure(const K&)          - measure a single element
 *       static M combine(const M&, const M&) - monoidal combine
 *       static M identity()                  - monoidal identity
 *       static int compare(const K&, const K&) - <0, 0, >0
 */

#include <cassert>
#include <cmath>
#include <functional>
#include <vector>

template <typename K, typename M, typename Traits> class Tree234 {
public:
  struct Node {
    int n;          // number of keys: 1, 2, or 3
    K keys[3];
    int children[4]; // -1 means no child (leaf edge)
    M measure;       // cached subtree measure
    Node() : n(0), measure(Traits::identity()) {
      children[0] = children[1] = children[2] = children[3] = -1;
    }
  };

  struct WeightResult {
    K key;
    double cum_before;
    int index;
    bool found;
  };

private:
  std::vector<Node> nodes_;
  std::vector<int> free_list_;
  int root_;
  int count_;

  int alloc_node() {
    int idx;
    if (!free_list_.empty()) {
      idx = free_list_.back();
      free_list_.pop_back();
      nodes_[idx] = Node();
    } else {
      idx = static_cast<int>(nodes_.size());
      nodes_.emplace_back();
    }
    return idx;
  }

  void free_node(int idx) {
    free_list_.push_back(idx);
  }

  bool is_leaf(int idx) const {
    return nodes_[idx].children[0] == -1;
  }

  bool is_4node(int idx) const {
    return nodes_[idx].n == 3;
  }

  void recompute_measure(int idx) {
    const Node &nd = nodes_[idx];
    M m = Traits::identity();
    for (int i = 0; i <= nd.n; i++) {
      if (nd.children[i] != -1) {
        m = Traits::combine(m, nodes_[nd.children[i]].measure);
      }
      if (i < nd.n) {
        m = Traits::combine(m, Traits::measure(nd.keys[i]));
      }
    }
    nodes_[idx].measure = m;
  }

  // Split a 4-node child at position child_pos of parent.
  // The child has keys k0,k1,k2 and children c0,c1,c2,c3.
  // After split: left gets (k0; c0,c1), right gets (k2; c2,c3),
  // k1 is pushed into parent at child_pos.
  // IMPORTANT: Do not hold Node& references across alloc_node().
  void split_child(int parent_idx, int child_pos) {
    int child_idx = nodes_[parent_idx].children[child_pos];
    assert(nodes_[child_idx].n == 3);

    // Save child data before alloc_node() may invalidate references
    K k0 = nodes_[child_idx].keys[0];
    K k1 = nodes_[child_idx].keys[1];
    K k2 = nodes_[child_idx].keys[2];
    int c0 = nodes_[child_idx].children[0];
    int c1 = nodes_[child_idx].children[1];
    int c2 = nodes_[child_idx].children[2];
    int c3 = nodes_[child_idx].children[3];

    // Create right node with k2, c2, c3
    int right_idx = alloc_node();
    // After alloc_node, re-access by index (not by saved reference)
    nodes_[right_idx].n = 1;
    nodes_[right_idx].keys[0] = k2;
    nodes_[right_idx].children[0] = c2;
    nodes_[right_idx].children[1] = c3;

    // Shrink child (left) to k0, c0, c1
    nodes_[child_idx].n = 1;
    nodes_[child_idx].keys[0] = k0;
    nodes_[child_idx].children[0] = c0;
    nodes_[child_idx].children[1] = c1;
    nodes_[child_idx].children[2] = -1;
    nodes_[child_idx].children[3] = -1;

    // Recompute measures for left and right
    recompute_measure(child_idx);
    recompute_measure(right_idx);

    // Insert mid_key (k1) into parent at child_pos
    // Shift keys and children to make room
    for (int i = nodes_[parent_idx].n; i > child_pos; i--) {
      nodes_[parent_idx].keys[i] = nodes_[parent_idx].keys[i - 1];
      nodes_[parent_idx].children[i + 1] = nodes_[parent_idx].children[i];
    }
    nodes_[parent_idx].keys[child_pos] = k1;
    nodes_[parent_idx].children[child_pos + 1] = right_idx;
    nodes_[parent_idx].n++;

    recompute_measure(parent_idx);
  }

  // Insert key into a non-full node's subtree.
  // Precondition: node at idx is not a 4-node.
  // IMPORTANT: Do not hold Node& references across calls that may grow nodes_.
  void insert_non_full(int idx, const K &key) {
    if (is_leaf(idx)) {
      // Insert key in sorted position
      int pos = nodes_[idx].n;
      while (pos > 0 && Traits::compare(key, nodes_[idx].keys[pos - 1]) < 0) {
        nodes_[idx].keys[pos] = nodes_[idx].keys[pos - 1];
        pos--;
      }
      nodes_[idx].keys[pos] = key;
      nodes_[idx].n++;
      recompute_measure(idx);
      return;
    }

    // Find child to descend into
    int pos = 0;
    while (pos < nodes_[idx].n &&
           Traits::compare(key, nodes_[idx].keys[pos]) >= 0) {
      pos++;
    }

    // If that child is a 4-node, split it first
    if (is_4node(nodes_[idx].children[pos])) {
      split_child(idx, pos);
      // After split, mid_key is at keys[pos].
      // Decide which side to go.
      if (Traits::compare(key, nodes_[idx].keys[pos]) >= 0) {
        pos++;
      }
    }

    insert_non_full(nodes_[idx].children[pos], key);
    recompute_measure(idx);
  }

  // In-order traversal helper
  template <typename F> void for_each_impl(int idx, F &&f) const {
    if (idx == -1)
      return;
    const Node &nd = nodes_[idx];
    for (int i = 0; i <= nd.n; i++) {
      if (nd.children[i] != -1) {
        for_each_impl(nd.children[i], f);
      }
      if (i < nd.n) {
        f(nd.keys[i]);
      }
    }
  }

  // Count elements in subtree
  int subtree_count(int idx) const {
    if (idx == -1)
      return 0;
    const Node &nd = nodes_[idx];
    int c = nd.n;
    for (int i = 0; i <= nd.n; i++) {
      if (nd.children[i] != -1)
        c += subtree_count(nd.children[i]);
    }
    return c;
  }

  // Helper: get weight from a measure using the provided weight_of function
  // find_by_weight walks down tracking cumulative weight
  WeightResult find_by_weight_impl(
      int idx, double target, double cum,
      int global_idx,
      const std::function<double(const M &)> &weight_of) const {
    if (idx == -1)
      return {{}, 0, 0, false};

    const Node &nd = nodes_[idx];
    double running_cum = cum;
    int running_idx = global_idx;

    for (int i = 0; i <= nd.n; i++) {
      // Process left child
      if (nd.children[i] != -1) {
        double child_weight = weight_of(nodes_[nd.children[i]].measure);
        if (running_cum + child_weight >= target) {
          // Target is in this child
          return find_by_weight_impl(nd.children[i], target, running_cum,
                                     running_idx, weight_of);
        }
        running_cum += child_weight;
        running_idx += subtree_count(nd.children[i]);
      }

      if (i < nd.n) {
        double key_weight = weight_of(Traits::measure(nd.keys[i]));
        if (running_cum + key_weight >= target) {
          return {nd.keys[i], running_cum, running_idx, true};
        }
        running_cum += key_weight;
        running_idx++;
      }
    }

    return {{}, 0, 0, false};
  }

  // Build balanced tree from sorted array recursively.
  // IMPORTANT: We must not hold references to nodes_ elements across
  // recursive calls, because those calls may grow the vector.
  int build_recursive(const std::vector<K> &sorted, int lo, int hi) {
    int n = hi - lo;
    if (n <= 0)
      return -1;

    if (n <= 3) {
      int idx = alloc_node();
      nodes_[idx].n = n;
      for (int i = 0; i < n; i++)
        nodes_[idx].keys[i] = sorted[lo + i];
      recompute_measure(idx);
      return idx;
    }

    // For larger ranges, create a 2-node or 3-node and recurse.
    // Build children FIRST (they may grow nodes_), then allocate parent.
    if (n <= 7) {
      int mid = lo + n / 2;
      int left = build_recursive(sorted, lo, mid);
      int right = build_recursive(sorted, mid + 1, hi);
      int idx = alloc_node();
      nodes_[idx].n = 1;
      nodes_[idx].keys[0] = sorted[mid];
      nodes_[idx].children[0] = left;
      nodes_[idx].children[1] = right;
      recompute_measure(idx);
      return idx;
    }

    // For even larger, use 3-node to keep tree balanced
    int third = n / 3;
    int m1 = lo + third;
    int m2 = lo + 2 * third + 1;
    int c0 = build_recursive(sorted, lo, m1);
    int c1 = build_recursive(sorted, m1 + 1, m2);
    int c2 = build_recursive(sorted, m2 + 1, hi);
    int idx = alloc_node();
    nodes_[idx].n = 2;
    nodes_[idx].keys[0] = sorted[m1];
    nodes_[idx].keys[1] = sorted[m2];
    nodes_[idx].children[0] = c0;
    nodes_[idx].children[1] = c1;
    nodes_[idx].children[2] = c2;
    recompute_measure(idx);
    return idx;
  }

public:
  Tree234() : root_(-1), count_(0) {}

  void insert(const K &key) {
    if (root_ == -1) {
      root_ = alloc_node();
      nodes_[root_].n = 1;
      nodes_[root_].keys[0] = key;
      recompute_measure(root_);
      count_++;
      return;
    }

    // If root is a 4-node, split it.
    // alloc_node may invalidate pointers, so save old_root first.
    if (is_4node(root_)) {
      int old_root = root_;
      root_ = alloc_node();
      // nodes_ may have been reallocated; access by index only
      nodes_[root_].children[0] = old_root;
      split_child(root_, 0);
    }

    insert_non_full(root_, key);
    count_++;
  }

  void clear() {
    nodes_.clear();
    free_list_.clear();
    root_ = -1;
    count_ = 0;
  }

  int size() const { return count_; }

  M root_measure() const {
    if (root_ == -1)
      return Traits::identity();
    return nodes_[root_].measure;
  }

  template <typename F> void for_each(F &&f) const {
    for_each_impl(root_, std::forward<F>(f));
  }

  WeightResult
  find_by_weight(double target,
                 const std::function<double(const M &)> &weight_of) const {
    if (root_ == -1)
      return {{}, 0, 0, false};
    return find_by_weight_impl(root_, target, 0.0, 0, weight_of);
  }

  void build_from_sorted(const std::vector<K> &sorted) {
    clear();
    if (sorted.empty())
      return;
    count_ = static_cast<int>(sorted.size());
    root_ = build_recursive(sorted, 0, static_cast<int>(sorted.size()));
  }

  // Access internals for update_key
  void update_key_at(int node_idx, int key_pos, const K &new_key) {
    nodes_[node_idx].keys[key_pos] = new_key;
    recompute_measure(node_idx);
    // Note: caller must recompute ancestors. For simplicity in t-digest,
    // we rebuild measures after modifications via build_from_sorted or
    // the path-based approach below.
  }

  // Find a key and return (node_idx, key_pos, path to root for measure update)
  struct FindResult {
    int node_idx;
    int key_pos;
    std::vector<int> path; // nodes from root to the found node (inclusive)
    bool found;
  };

  FindResult find_key(const K &key) const {
    FindResult result;
    result.found = false;
    if (root_ == -1)
      return result;

    int idx = root_;
    result.path.push_back(idx);

    while (idx != -1) {
      const Node &nd = nodes_[idx];
      for (int i = 0; i < nd.n; i++) {
        if (Traits::compare(key, nd.keys[i]) == 0) {
          result.node_idx = idx;
          result.key_pos = i;
          result.found = true;
          return result;
        }
      }
      // Find child to descend
      int pos = 0;
      while (pos < nd.n && Traits::compare(key, nd.keys[pos]) >= 0)
        pos++;
      idx = nd.children[pos];
      if (idx != -1)
        result.path.push_back(idx);
    }
    return result;
  }

  // Update a key by path and recompute measures along the path
  void update_key_with_path(const std::vector<int> &path, int node_idx,
                            int key_pos, const K &new_key) {
    nodes_[node_idx].keys[key_pos] = new_key;
    // Recompute measures from bottom to top
    for (int i = static_cast<int>(path.size()) - 1; i >= 0; i--) {
      recompute_measure(path[i]);
    }
  }

  // Collect all keys in-order into a vector
  void collect(std::vector<K> &out) const {
    out.clear();
    out.reserve(count_);
    for_each([&out](const K &k) { out.push_back(k); });
  }

  // Find neighbors of a value and cumulative weights
  struct Neighbors {
    K left_key, right_key;
    double left_cum;  // cumulative weight before left neighbor
    double right_cum; // cumulative weight before right neighbor
    int left_index, right_index; // global indices
    bool has_left, has_right;

    // Path info for in-place update
    int left_node, left_pos;
    int right_node, right_pos;
    std::vector<int> left_path, right_path;
  };

  Neighbors find_neighbors(
      const K &key,
      const std::function<double(const M &)> &weight_of) const {
    Neighbors result;
    result.has_left = false;
    result.has_right = false;
    result.left_cum = 0;
    result.right_cum = 0;
    result.left_index = -1;
    result.right_index = -1;

    if (root_ == -1)
      return result;

    // Walk the tree tracking predecessor and successor
    int idx = root_;
    double cum = 0.0;
    int global_idx = 0;

    // We'll do an iterative descent
    struct StackEntry {
      int node_idx;
      int key_idx; // which key we're about to process (or child to descend)
    };

    // Simple approach: collect all centroids and find neighbors by binary search
    // This is O(n) but compress() already does O(n) work, so it's acceptable.
    std::vector<K> all;
    all.reserve(count_);
    for_each([&all](const K &k) { all.push_back(k); });

    double running_cum = 0.0;
    int best_left = -1, best_right = -1;

    for (int i = 0; i < static_cast<int>(all.size()); i++) {
      int cmp = Traits::compare(all[i], key);
      if (cmp <= 0) {
        best_left = i;
        result.left_key = all[i];
        result.left_cum = running_cum;
        result.left_index = i;
        result.has_left = true;
      }
      if (cmp >= 0 && !result.has_right) {
        best_right = i;
        result.right_key = all[i];
        result.right_cum = running_cum;
        result.right_index = i;
        result.has_right = true;
      }
      running_cum += weight_of(Traits::measure(all[i]));
    }

    return result;
  }
};
