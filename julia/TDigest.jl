"""
Dunning t-digest for online quantile estimation.
Merging digest variant with K_1 (arcsine) scale function.
Uses an array-backed 2-3-4 tree with monoidal measures.
Pure Julia -- no external packages.
"""
module TDigestModule

include("Tree234.jl")
using .Tree234Module

export TDigest, add!, compress!, quantile, cdf, merge!, centroid_count

struct Centroid
    mean::Float64
    weight::Float64
end

struct TdMeasure
    weight::Float64
    count::Int
    max_mean::Float64
    mean_weight_sum::Float64
end

const DEFAULT_DELTA = 100.0
const BUFFER_FACTOR = 5

# Trait functions for Tree234
function _td_measure(c::Centroid)::TdMeasure
    TdMeasure(c.weight, 1, c.mean, c.mean * c.weight)
end

function _td_combine(a::TdMeasure, b::TdMeasure)::TdMeasure
    TdMeasure(a.weight + b.weight, a.count + b.count,
              max(a.max_mean, b.max_mean),
              a.mean_weight_sum + b.mean_weight_sum)
end

function _td_identity()::TdMeasure
    TdMeasure(0.0, 0, -Inf, 0.0)
end

function _td_compare(a::Centroid, b::Centroid)::Int
    a.mean < b.mean ? -1 : (a.mean > b.mean ? 1 : 0)
end

mutable struct TDigest
    delta::Float64
    tree::Tree234{Centroid,TdMeasure}
    buffer::Vector{Centroid}
    total_weight::Float64
    min::Float64
    max::Float64
    buffer_cap::Int

    function TDigest(delta::Real = DEFAULT_DELTA)
        t = Tree234{Centroid,TdMeasure}(_td_measure, _td_combine,
                                         _td_identity, _td_compare)
        new(Float64(delta), t, Centroid[], 0.0, Inf, -Inf,
            ceil(Int, Float64(delta) * BUFFER_FACTOR))
    end
end

# -- Scale function -------------------------------------------------------

function _k(td::TDigest, q::Float64)::Float64
    (td.delta / (2.0 * pi)) * asin(2.0 * q - 1.0)
end

function _merge_centroid!(centroids::Vector{Centroid}, c::Centroid)
    last = centroids[end]
    new_weight = last.weight + c.weight
    new_mean = (last.mean * last.weight + c.mean * c.weight) / new_weight
    centroids[end] = Centroid(new_mean, new_weight)
end

# -- Mutation -------------------------------------------------------------

function add!(td::TDigest, value::Real, weight::Real = 1.0)
    v = Float64(value)
    w = Float64(weight)
    push!(td.buffer, Centroid(v, w))
    td.total_weight += w
    if v < td.min
        td.min = v
    end
    if v > td.max
        td.max = v
    end
    if length(td.buffer) >= td.buffer_cap
        compress!(td)
    end
    td
end

function compress!(td::TDigest)
    if isempty(td.buffer) && length(td.tree) <= 1
        return td
    end

    # Collect all centroids from tree and buffer
    all = collect_keys(td.tree)
    append!(all, td.buffer)
    empty!(td.buffer)
    sort!(all; by = c -> c.mean)

    new_centroids = Centroid[all[1]]
    weight_so_far = 0.0
    n = td.total_weight

    for i in 2:length(all)
        proposed = new_centroids[end].weight + all[i].weight
        q0 = weight_so_far / n
        q1 = (weight_so_far + proposed) / n

        if proposed <= 1 && length(all) > 1
            _merge_centroid!(new_centroids, all[i])
        elseif _k(td, q1) - _k(td, q0) <= 1.0
            _merge_centroid!(new_centroids, all[i])
        else
            weight_so_far += new_centroids[end].weight
            push!(new_centroids, Centroid(all[i].mean, all[i].weight))
        end
    end

    # Rebuild tree from sorted merged centroids
    build_from_sorted!(td.tree, new_centroids)
    td
end

# -- Queries --------------------------------------------------------------

function quantile(td::TDigest, q::Float64)
    if !isempty(td.buffer)
        compress!(td)
    end
    sz = length(td.tree)
    if sz == 0
        return nothing
    end

    centroids = collect_keys(td.tree)

    if sz == 1
        return centroids[1].mean
    end

    q = clamp(q, 0.0, 1.0)
    n = td.total_weight
    target = q * n
    nc = length(centroids)

    # Build prefix sums
    cum = Vector{Float64}(undef, nc)
    cum[1] = centroids[1].weight
    for i in 2:nc
        cum[i] = cum[i - 1] + centroids[i].weight
    end

    # Handle first centroid edge case
    first_c = centroids[1]
    if target < first_c.weight / 2.0
        if first_c.weight == 1.0
            return td.min
        end
        return td.min + (first_c.mean - td.min) * (target / (first_c.weight / 2.0))
    end

    # Handle last centroid edge case
    last_c = centroids[nc]
    if target > n - last_c.weight / 2.0
        if last_c.weight == 1.0
            return td.max
        end
        remaining = n - last_c.weight / 2.0
        return last_c.mean + (td.max - last_c.mean) * ((target - remaining) / (last_c.weight / 2.0))
    end

    # Binary search for position
    lo_idx = 1
    hi_idx = nc
    while lo_idx < hi_idx
        mid_idx = div(lo_idx + hi_idx, 2)
        if cum[mid_idx] < target
            lo_idx = mid_idx + 1
        else
            hi_idx = mid_idx
        end
    end
    idx = lo_idx

    if idx >= nc
        idx = nc - 1
    end
    if idx < 1
        idx = 1
    end

    cumulative = idx > 1 ? cum[idx - 1] : 0.0
    c = centroids[idx]
    mid_val = cumulative + c.weight / 2.0

    if idx > 1 && target < mid_val
        idx -= 1
        cumulative = idx > 1 ? cum[idx - 1] : 0.0
        c2 = centroids[idx]
        mid2 = cumulative + c2.weight / 2.0
        next_c = centroids[idx + 1]
        next_mid = cumulative + c2.weight + next_c.weight / 2.0
        frac = next_mid == mid2 ? 0.5 : (target - mid2) / (next_mid - mid2)
        return c2.mean + frac * (next_c.mean - c2.mean)
    end

    if idx == nc
        return c.mean
    end

    next_c = centroids[idx + 1]
    next_mid = cumulative + c.weight + next_c.weight / 2.0

    if target <= next_mid
        frac = next_mid == mid_val ? 0.5 : (target - mid_val) / (next_mid - mid_val)
        return c.mean + frac * (next_c.mean - c.mean)
    end

    td.max
end

function cdf(td::TDigest, x::Real)
    x = Float64(x)
    if !isempty(td.buffer)
        compress!(td)
    end
    sz = length(td.tree)
    if sz == 0
        return nothing
    end
    if x <= td.min
        return 0.0
    end
    if x >= td.max
        return 1.0
    end

    centroids = collect_keys(td.tree)
    nc = length(centroids)
    n = td.total_weight

    # Build prefix sums
    cum = Vector{Float64}(undef, nc)
    cum[1] = centroids[1].weight
    for i in 2:nc
        cum[i] = cum[i - 1] + centroids[i].weight
    end

    # Binary search for position: find first centroid with mean >= x
    means = [c.mean for c in centroids]
    pos = searchsortedfirst(means, x)

    # x is less than the first centroid's mean
    if pos == 1
        c = centroids[1]
        if x < c.mean
            inner_w = c.weight / 2.0
            frac = c.mean == td.min ? 1.0 : (x - td.min) / (c.mean - td.min)
            return (inner_w * frac) / n
        end
        return (c.weight / 2.0) / n
    end

    # x >= all centroid means
    if pos > nc
        c = centroids[nc]
        cumulative = nc > 1 ? cum[nc - 1] : 0.0
        if x > c.mean
            right_w = n - cumulative - c.weight / 2.0
            frac = td.max == c.mean ? 0.0 : (x - c.mean) / (td.max - c.mean)
            return (cumulative + c.weight / 2.0 + right_w * frac) / n
        end
        return (cumulative + c.weight / 2.0) / n
    end

    # x is between centroids[pos-1].mean and centroids[pos].mean
    i = pos - 1
    c = centroids[i]
    next_c = centroids[pos]

    cumulative = i > 1 ? cum[i - 1] : 0.0
    mid_cdf = cumulative + c.weight / 2.0
    next_cumulative = cumulative + c.weight
    next_mid = next_cumulative + next_c.weight / 2.0

    if i == nc
        if x > c.mean
            right_w = n - cumulative - c.weight / 2.0
            frac = td.max == c.mean ? 0.0 : (x - c.mean) / (td.max - c.mean)
            return (cumulative + c.weight / 2.0 + right_w * frac) / n
        end
        return (cumulative + c.weight / 2.0) / n
    end

    if x < next_c.mean
        if c.mean == next_c.mean
            return (mid_cdf + (next_mid - mid_cdf) / 2.0) / n
        end
        frac = (x - c.mean) / (next_c.mean - c.mean)
        return (mid_cdf + frac * (next_mid - mid_cdf)) / n
    end

    return next_mid / n
end

function merge!(td::TDigest, other::TDigest)
    if !isempty(other.buffer)
        compress!(other)
    end
    other_centroids = collect_keys(other.tree)
    for c in other_centroids
        add!(td, c.mean, c.weight)
    end
    td
end

function centroid_count(td::TDigest)::Int
    if !isempty(td.buffer)
        compress!(td)
    end
    length(td.tree)
end

end # module
