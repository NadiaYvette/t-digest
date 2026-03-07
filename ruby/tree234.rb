# frozen_string_literal: true

# Generic array-backed 2-3-4 tree with monoidal measures.
#
# Constructor takes four callables:
#   measure_fn  - measure a single key -> M
#   combine_fn  - combine two measures (M, M) -> M
#   identity_fn - monoidal identity () -> M
#   compare_fn  - compare two keys (a, b) -> <0, 0, >0

class Tree234
  Node = Struct.new(:n, :keys, :children, :measure)

  WeightResult = Struct.new(:key, :cum_before, :index, :found)

  def initialize(measure_fn:, combine_fn:, identity_fn:, compare_fn:)
    @measure_fn  = measure_fn
    @combine_fn  = combine_fn
    @identity_fn = identity_fn
    @compare_fn  = compare_fn
    @nodes     = []
    @free_list = []
    @root      = -1
    @count     = 0
  end

  def size
    @count
  end

  def root_measure
    return @identity_fn.call if @root == -1
    @nodes[@root].measure
  end

  # Insert a key into the tree (top-down splitting of 4-nodes).
  def insert(key)
    if @root == -1
      @root = alloc_node
      nd = @nodes[@root]
      nd.n = 1
      nd.keys[0] = key
      recompute_measure(@root)
      @count += 1
      return
    end

    # If root is a 4-node, split it by creating a new root.
    if four_node?(@root)
      old_root = @root
      @root = alloc_node
      @nodes[@root].children[0] = old_root
      split_child(@root, 0)
    end

    insert_non_full(@root, key)
    @count += 1
  end

  # Collect all keys in-order into an array.
  def collect
    out = []
    for_each_impl(@root) { |k| out << k }
    out
  end

  # In-order traversal yielding each key.
  def for_each(&block)
    for_each_impl(@root, &block)
  end

  # Find a key by cumulative weight. weight_of is a lambda(measure) -> Float.
  # Returns a WeightResult.
  def find_by_weight(target, weight_of)
    return WeightResult.new(nil, 0, 0, false) if @root == -1
    find_by_weight_impl(@root, target, 0.0, 0, weight_of)
  end

  # Build a balanced tree from a sorted array (replaces current contents).
  def build_from_sorted(sorted)
    clear
    return if sorted.empty?
    @count = sorted.size
    @root = build_recursive(sorted, 0, sorted.size)
  end

  def clear
    @nodes.clear
    @free_list.clear
    @root = -1
    @count = 0
  end

  private

  def alloc_node
    if @free_list.empty?
      idx = @nodes.size
      @nodes << Node.new(0, [nil, nil, nil], [-1, -1, -1, -1], @identity_fn.call)
      idx
    else
      idx = @free_list.pop
      nd = @nodes[idx]
      nd.n = 0
      nd.keys[0] = nd.keys[1] = nd.keys[2] = nil
      nd.children[0] = nd.children[1] = nd.children[2] = nd.children[3] = -1
      nd.measure = @identity_fn.call
      idx
    end
  end

  def leaf?(idx)
    @nodes[idx].children[0] == -1
  end

  def four_node?(idx)
    @nodes[idx].n == 3
  end

  def recompute_measure(idx)
    nd = @nodes[idx]
    m = @identity_fn.call
    (0..nd.n).each do |i|
      if nd.children[i] != -1
        m = @combine_fn.call(m, @nodes[nd.children[i]].measure)
      end
      if i < nd.n
        m = @combine_fn.call(m, @measure_fn.call(nd.keys[i]))
      end
    end
    nd.measure = m
  end

  # Split a 4-node child at child_pos of parent.
  def split_child(parent_idx, child_pos)
    child_idx = @nodes[parent_idx].children[child_pos]
    child = @nodes[child_idx]

    k0 = child.keys[0]
    k1 = child.keys[1]
    k2 = child.keys[2]
    c0 = child.children[0]
    c1 = child.children[1]
    c2 = child.children[2]
    c3 = child.children[3]

    right_idx = alloc_node
    # After alloc_node, re-fetch by index
    right = @nodes[right_idx]
    right.n = 1
    right.keys[0] = k2
    right.children[0] = c2
    right.children[1] = c3

    left = @nodes[child_idx]
    left.n = 1
    left.keys[0] = k0
    left.keys[1] = nil
    left.keys[2] = nil
    left.children[0] = c0
    left.children[1] = c1
    left.children[2] = -1
    left.children[3] = -1

    recompute_measure(child_idx)
    recompute_measure(right_idx)

    parent = @nodes[parent_idx]
    # Shift keys and children to make room
    i = parent.n
    while i > child_pos
      parent.keys[i] = parent.keys[i - 1]
      parent.children[i + 1] = parent.children[i]
      i -= 1
    end
    parent.keys[child_pos] = k1
    parent.children[child_pos + 1] = right_idx
    parent.n += 1

    recompute_measure(parent_idx)
  end

  # Insert key into a non-full node's subtree.
  def insert_non_full(idx, key)
    nd = @nodes[idx]

    if leaf?(idx)
      pos = nd.n
      while pos > 0 && @compare_fn.call(key, nd.keys[pos - 1]) < 0
        nd.keys[pos] = nd.keys[pos - 1]
        pos -= 1
      end
      nd.keys[pos] = key
      nd.n += 1
      recompute_measure(idx)
      return
    end

    # Find child to descend into
    pos = 0
    while pos < nd.n && @compare_fn.call(key, nd.keys[pos]) >= 0
      pos += 1
    end

    # If that child is a 4-node, split it first
    if four_node?(nd.children[pos])
      split_child(idx, pos)
      # Re-fetch nd since split_child may have changed it
      nd = @nodes[idx]
      if @compare_fn.call(key, nd.keys[pos]) >= 0
        pos += 1
      end
    end

    insert_non_full(nd.children[pos], key)
    recompute_measure(idx)
  end

  def for_each_impl(idx, &block)
    return if idx == -1
    nd = @nodes[idx]
    (0..nd.n).each do |i|
      for_each_impl(nd.children[i], &block) if nd.children[i] != -1
      yield nd.keys[i] if i < nd.n
    end
  end

  def subtree_count(idx)
    return 0 if idx == -1
    nd = @nodes[idx]
    c = nd.n
    (0..nd.n).each do |i|
      c += subtree_count(nd.children[i]) if nd.children[i] != -1
    end
    c
  end

  def find_by_weight_impl(idx, target, cum, global_idx, weight_of)
    return WeightResult.new(nil, 0, 0, false) if idx == -1

    nd = @nodes[idx]
    running_cum = cum
    running_idx = global_idx

    (0..nd.n).each do |i|
      if nd.children[i] != -1
        child_weight = weight_of.call(@nodes[nd.children[i]].measure)
        if running_cum + child_weight >= target
          return find_by_weight_impl(nd.children[i], target, running_cum, running_idx, weight_of)
        end
        running_cum += child_weight
        running_idx += subtree_count(nd.children[i])
      end

      if i < nd.n
        key_weight = weight_of.call(@measure_fn.call(nd.keys[i]))
        if running_cum + key_weight >= target
          return WeightResult.new(nd.keys[i], running_cum, running_idx, true)
        end
        running_cum += key_weight
        running_idx += 1
      end
    end

    WeightResult.new(nil, 0, 0, false)
  end

  def build_recursive(sorted, lo, hi)
    n = hi - lo
    return -1 if n <= 0

    if n <= 3
      idx = alloc_node
      nd = @nodes[idx]
      nd.n = n
      n.times { |i| nd.keys[i] = sorted[lo + i] }
      recompute_measure(idx)
      return idx
    end

    if n <= 7
      mid = lo + n / 2
      left = build_recursive(sorted, lo, mid)
      right = build_recursive(sorted, mid + 1, hi)
      idx = alloc_node
      nd = @nodes[idx]
      nd.n = 1
      nd.keys[0] = sorted[mid]
      nd.children[0] = left
      nd.children[1] = right
      recompute_measure(idx)
      return idx
    end

    # For larger ranges, use 3-node
    third = n / 3
    m1 = lo + third
    m2 = lo + 2 * third + 1
    c0 = build_recursive(sorted, lo, m1)
    c1 = build_recursive(sorted, m1 + 1, m2)
    c2 = build_recursive(sorted, m2 + 1, hi)
    idx = alloc_node
    nd = @nodes[idx]
    nd.n = 2
    nd.keys[0] = sorted[m1]
    nd.keys[1] = sorted[m2]
    nd.children[0] = c0
    nd.children[1] = c1
    nd.children[2] = c2
    recompute_measure(idx)
    idx
  end
end
