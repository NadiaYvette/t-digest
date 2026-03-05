"""
Dunning t-digest for online quantile estimation.
Merging digest variant with K_1 (arcsine) scale function.
Pure Julia -- no external packages.
"""
module TDigestModule

export TDigest, add!, compress!, quantile, cdf, merge!, centroid_count

struct Centroid
    mean::Float64
    weight::Float64
end

const DEFAULT_DELTA = 100.0
const BUFFER_FACTOR = 5

mutable struct TDigest
    delta::Float64
    centroids::Vector{Centroid}
    buffer::Vector{Centroid}
    total_weight::Float64
    min::Float64
    max::Float64
    buffer_cap::Int

    function TDigest(delta::Real = DEFAULT_DELTA)
        new(Float64(delta), Centroid[], Centroid[], 0.0, Inf, -Inf,
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
    if isempty(td.buffer) && length(td.centroids) <= 1
        return td
    end

    all = vcat(td.centroids, td.buffer)
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

    td.centroids = new_centroids
    td
end

# -- Queries --------------------------------------------------------------

function quantile(td::TDigest, q::Float64)
    if !isempty(td.buffer)
        compress!(td)
    end
    if isempty(td.centroids)
        return nothing
    end
    if length(td.centroids) == 1
        return td.centroids[1].mean
    end

    q = clamp(q, 0.0, 1.0)
    n = td.total_weight
    target = q * n
    cumulative = 0.0
    nc = length(td.centroids)

    for i in 1:nc
        c = td.centroids[i]
        mid = cumulative + c.weight / 2.0

        if i == 1
            if target < c.weight / 2.0
                if c.weight == 1
                    return td.min
                end
                return td.min + (c.mean - td.min) * (target / (c.weight / 2.0))
            end
        end

        if i == nc
            if target > n - c.weight / 2.0
                if c.weight == 1
                    return td.max
                end
                remaining = n - c.weight / 2.0
                return c.mean + (td.max - c.mean) * ((target - remaining) / (c.weight / 2.0))
            end
            return c.mean
        end

        next_c = td.centroids[i + 1]
        next_mid = cumulative + c.weight + next_c.weight / 2.0

        if target <= next_mid
            frac = next_mid == mid ? 0.5 : (target - mid) / (next_mid - mid)
            return c.mean + frac * (next_c.mean - c.mean)
        end

        cumulative += c.weight
    end

    td.max
end

function cdf(td::TDigest, x::Real)
    x = Float64(x)
    if !isempty(td.buffer)
        compress!(td)
    end
    if isempty(td.centroids)
        return nothing
    end
    if x <= td.min
        return 0.0
    end
    if x >= td.max
        return 1.0
    end

    n = td.total_weight
    cumulative = 0.0
    nc = length(td.centroids)

    for i in 1:nc
        c = td.centroids[i]

        if i == 1
            if x < c.mean
                inner_w = c.weight / 2.0
                frac = c.mean == td.min ? 1.0 : (x - td.min) / (c.mean - td.min)
                return (inner_w * frac) / n
            elseif x == c.mean
                return (c.weight / 2.0) / n
            end
        end

        if i == nc
            if x > c.mean
                inner_w = c.weight / 2.0
                right_w = n - cumulative - c.weight / 2.0
                frac = td.max == c.mean ? 0.0 : (x - c.mean) / (td.max - c.mean)
                return (cumulative + c.weight / 2.0 + right_w * frac) / n
            else
                return (cumulative + c.weight / 2.0) / n
            end
        end

        next_c = td.centroids[i + 1]
        next_cumulative = cumulative + c.weight
        mid_val = cumulative + c.weight / 2.0
        next_mid = next_cumulative + next_c.weight / 2.0

        if x < next_c.mean
            if c.mean == next_c.mean
                return (mid_val + (next_mid - mid_val) / 2.0) / n
            end
            frac = (x - c.mean) / (next_c.mean - c.mean)
            return (mid_val + frac * (next_mid - mid_val)) / n
        end

        cumulative += c.weight
    end

    1.0
end

function merge!(td::TDigest, other::TDigest)
    if !isempty(other.buffer)
        compress!(other)
    end
    for c in other.centroids
        add!(td, c.mean, c.weight)
    end
    td
end

function centroid_count(td::TDigest)::Int
    if !isempty(td.buffer)
        compress!(td)
    end
    length(td.centroids)
end

end # module
