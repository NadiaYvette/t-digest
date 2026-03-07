"""
Generic array-backed 2-3-4 tree with monoidal measures.

Parametric type Tree234{K,M} where:
  K - key/element type (stored in sorted order)
  M - measure type (monoidal annotation on subtrees)

Trait functions passed to constructor:
  measure_fn(key::K) -> M
  combine_fn(a::M, b::M) -> M
  identity_fn() -> M
  compare_fn(a::K, b::K) -> Int  (-1, 0, +1)
"""
module Tree234Module

export Tree234, insert!, collect_keys, find_by_weight, build_from_sorted!, clear!

mutable struct Node{K,M}
    n::Int              # number of keys: 0-3
    keys::Vector{K}     # length 3
    children::Vector{Int}  # length 4, -1 means no child
    measure::M
end

struct WeightResult{K}
    key::K
    cum_before::Float64
    index::Int
    found::Bool
end

mutable struct Tree234{K,M}
    nodes::Vector{Node{K,M}}
    free_list::Vector{Int}
    root::Int           # -1 means empty
    count::Int

    # Trait functions
    measure_fn::Function
    combine_fn::Function
    identity_fn::Function
    compare_fn::Function

    function Tree234{K,M}(measure_fn, combine_fn, identity_fn, compare_fn) where {K,M}
        new{K,M}(Node{K,M}[], Int[], -1, 0,
                 measure_fn, combine_fn, identity_fn, compare_fn)
    end
end

function _make_node(t::Tree234{K,M}) where {K,M}
    id = t.identity_fn()
    # We need a default key; use undefined storage via Vector
    Node{K,M}(0, Vector{K}(undef, 3), fill(-1, 4), id)
end

function _alloc_node!(t::Tree234{K,M}) where {K,M}
    if !isempty(t.free_list)
        idx = pop!(t.free_list)
        nd = _make_node(t)
        t.nodes[idx] = nd
        return idx
    else
        push!(t.nodes, _make_node(t))
        return length(t.nodes)
    end
end

function _free_node!(t::Tree234, idx::Int)
    push!(t.free_list, idx)
end

@inline function _is_leaf(t::Tree234, idx::Int)
    t.nodes[idx].children[1] == -1
end

@inline function _is_4node(t::Tree234, idx::Int)
    t.nodes[idx].n == 3
end

function _recompute_measure!(t::Tree234{K,M}, idx::Int) where {K,M}
    nd = t.nodes[idx]
    m = t.identity_fn()
    for i in 1:(nd.n + 1)
        if nd.children[i] != -1
            m = t.combine_fn(m, t.nodes[nd.children[i]].measure)
        end
        if i <= nd.n
            m = t.combine_fn(m, t.measure_fn(nd.keys[i]))
        end
    end
    t.nodes[idx].measure = m
    nothing
end

function _split_child!(t::Tree234{K,M}, parent_idx::Int, child_pos::Int) where {K,M}
    child_idx = t.nodes[parent_idx].children[child_pos]

    # Save child data before alloc may invalidate
    k1 = t.nodes[child_idx].keys[1]
    k2 = t.nodes[child_idx].keys[2]
    k3 = t.nodes[child_idx].keys[3]
    c1 = t.nodes[child_idx].children[1]
    c2 = t.nodes[child_idx].children[2]
    c3 = t.nodes[child_idx].children[3]
    c4 = t.nodes[child_idx].children[4]

    # Create right node with k3, c3, c4
    right_idx = _alloc_node!(t)
    t.nodes[right_idx].n = 1
    t.nodes[right_idx].keys[1] = k3
    t.nodes[right_idx].children[1] = c3
    t.nodes[right_idx].children[2] = c4

    # Shrink child (left) to k1, c1, c2
    t.nodes[child_idx].n = 1
    t.nodes[child_idx].keys[1] = k1
    t.nodes[child_idx].children[1] = c1
    t.nodes[child_idx].children[2] = c2
    t.nodes[child_idx].children[3] = -1
    t.nodes[child_idx].children[4] = -1

    _recompute_measure!(t, child_idx)
    _recompute_measure!(t, right_idx)

    # Insert mid key (k2) into parent at child_pos
    pn = t.nodes[parent_idx].n
    # Shift keys and children right
    for i in pn:-1:child_pos
        t.nodes[parent_idx].keys[i + 1] = t.nodes[parent_idx].keys[i]
        t.nodes[parent_idx].children[i + 2] = t.nodes[parent_idx].children[i + 1]
    end
    t.nodes[parent_idx].keys[child_pos] = k2
    t.nodes[parent_idx].children[child_pos + 1] = right_idx
    t.nodes[parent_idx].n += 1

    _recompute_measure!(t, parent_idx)
    nothing
end

function _insert_non_full!(t::Tree234{K,M}, idx::Int, key::K) where {K,M}
    if _is_leaf(t, idx)
        # Insert key in sorted position
        pos = t.nodes[idx].n + 1
        while pos > 1 && t.compare_fn(key, t.nodes[idx].keys[pos - 1]) < 0
            t.nodes[idx].keys[pos] = t.nodes[idx].keys[pos - 1]
            pos -= 1
        end
        t.nodes[idx].keys[pos] = key
        t.nodes[idx].n += 1
        _recompute_measure!(t, idx)
        return
    end

    # Find child to descend into (1-based)
    pos = 1
    while pos <= t.nodes[idx].n && t.compare_fn(key, t.nodes[idx].keys[pos]) >= 0
        pos += 1
    end

    # If that child is a 4-node, split it first
    if _is_4node(t, t.nodes[idx].children[pos])
        _split_child!(t, idx, pos)
        # After split, mid key is at keys[pos]. Decide which side.
        if t.compare_fn(key, t.nodes[idx].keys[pos]) >= 0
            pos += 1
        end
    end

    _insert_non_full!(t, t.nodes[idx].children[pos], key)
    _recompute_measure!(t, idx)
    nothing
end

function insert!(t::Tree234{K,M}, key::K) where {K,M}
    if t.root == -1
        t.root = _alloc_node!(t)
        t.nodes[t.root].n = 1
        t.nodes[t.root].keys[1] = key
        _recompute_measure!(t, t.root)
        t.count += 1
        return t
    end

    # If root is a 4-node, split it
    if _is_4node(t, t.root)
        old_root = t.root
        t.root = _alloc_node!(t)
        t.nodes[t.root].children[1] = old_root
        _split_child!(t, t.root, 1)
    end

    _insert_non_full!(t, t.root, key)
    t.count += 1
    return t
end

# In-order traversal
function _for_each(t::Tree234{K,M}, idx::Int, f::Function) where {K,M}
    if idx == -1
        return
    end
    nd = t.nodes[idx]
    for i in 1:(nd.n + 1)
        if nd.children[i] != -1
            _for_each(t, nd.children[i], f)
        end
        if i <= nd.n
            f(nd.keys[i])
        end
    end
    nothing
end

function collect_keys(t::Tree234{K,M}) where {K,M}
    result = K[]
    sizehint!(result, t.count)
    if t.root != -1
        _for_each(t, t.root, k -> push!(result, k))
    end
    result
end

function _subtree_count(t::Tree234, idx::Int)::Int
    if idx == -1
        return 0
    end
    nd = t.nodes[idx]
    c = nd.n
    for i in 1:(nd.n + 1)
        if nd.children[i] != -1
            c += _subtree_count(t, nd.children[i])
        end
    end
    c
end

function _find_by_weight_impl(t::Tree234{K,M}, idx::Int, target::Float64,
                               cum::Float64, global_idx::Int,
                               weight_of::Function) where {K,M}
    if idx == -1
        return nothing
    end

    nd = t.nodes[idx]
    running_cum = cum
    running_idx = global_idx

    for i in 1:(nd.n + 1)
        # Process child
        if nd.children[i] != -1
            child_weight = weight_of(t.nodes[nd.children[i]].measure)
            if running_cum + child_weight >= target
                return _find_by_weight_impl(t, nd.children[i], target,
                                             running_cum, running_idx, weight_of)
            end
            running_cum += child_weight
            running_idx += _subtree_count(t, nd.children[i])
        end

        if i <= nd.n
            key_weight = weight_of(t.measure_fn(nd.keys[i]))
            if running_cum + key_weight >= target
                return WeightResult{K}(nd.keys[i], running_cum, running_idx, true)
            end
            running_cum += key_weight
            running_idx += 1
        end
    end

    return nothing
end

function find_by_weight(t::Tree234{K,M}, target::Float64, weight_of::Function) where {K,M}
    if t.root == -1
        return nothing
    end
    _find_by_weight_impl(t, t.root, target, 0.0, 0, weight_of)
end

function _build_recursive!(t::Tree234{K,M}, sorted::Vector{K}, lo::Int, hi::Int) where {K,M}
    n = hi - lo
    if n <= 0
        return -1
    end

    if n <= 3
        idx = _alloc_node!(t)
        t.nodes[idx].n = n
        for i in 1:n
            t.nodes[idx].keys[i] = sorted[lo + i]  # sorted is 1-based, lo is 0-based offset
        end
        _recompute_measure!(t, idx)
        return idx
    end

    if n <= 7
        mid = lo + div(n, 2)
        left = _build_recursive!(t, sorted, lo, mid)
        right = _build_recursive!(t, sorted, mid + 1, hi)
        idx = _alloc_node!(t)
        t.nodes[idx].n = 1
        t.nodes[idx].keys[1] = sorted[mid + 1]  # 1-based
        t.nodes[idx].children[1] = left
        t.nodes[idx].children[2] = right
        _recompute_measure!(t, idx)
        return idx
    end

    # Use 3-node for larger ranges
    third = div(n, 3)
    m1 = lo + third
    m2 = lo + 2 * third + 1
    c0 = _build_recursive!(t, sorted, lo, m1)
    c1 = _build_recursive!(t, sorted, m1 + 1, m2)
    c2 = _build_recursive!(t, sorted, m2 + 1, hi)
    idx = _alloc_node!(t)
    t.nodes[idx].n = 2
    t.nodes[idx].keys[1] = sorted[m1 + 1]  # 1-based
    t.nodes[idx].keys[2] = sorted[m2 + 1]  # 1-based
    t.nodes[idx].children[1] = c0
    t.nodes[idx].children[2] = c1
    t.nodes[idx].children[3] = c2
    _recompute_measure!(t, idx)
    return idx
end

function build_from_sorted!(t::Tree234{K,M}, sorted::Vector{K}) where {K,M}
    clear!(t)
    if isempty(sorted)
        return t
    end
    t.count = length(sorted)
    # _build_recursive uses 0-based lo/hi like the C++ version
    # sorted[lo+1] .. sorted[hi] in 1-based Julia indexing
    t.root = _build_recursive!(t, sorted, 0, length(sorted))
    return t
end

function clear!(t::Tree234)
    empty!(t.nodes)
    empty!(t.free_list)
    t.root = -1
    t.count = 0
    return t
end

function Base.length(t::Tree234)
    t.count
end

function root_measure(t::Tree234{K,M}) where {K,M}
    if t.root == -1
        return t.identity_fn()
    end
    t.nodes[t.root].measure
end

end # module
