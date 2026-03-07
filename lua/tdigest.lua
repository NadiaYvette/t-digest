-- Dunning t-digest for online quantile estimation.
-- Merging digest variant with K_1 (arcsine) scale function.
-- Uses an array-backed 2-3-4 tree with monoidal measures.

local Tree234 = require("tree234")

local TDigest = {}
TDigest.__index = TDigest

local DEFAULT_DELTA = 100
local BUFFER_FACTOR = 5

-- Centroid measure: {weight, count, max_mean, mean_weight_sum}
local function centroid_measure(c)
    return {
        weight = c.weight,
        count = 1,
        max_mean = c.mean,
        mean_weight_sum = c.mean * c.weight,
    }
end

local function combine_measure(a, b)
    return {
        weight = a.weight + b.weight,
        count = a.count + b.count,
        max_mean = math.max(a.max_mean, b.max_mean),
        mean_weight_sum = a.mean_weight_sum + b.mean_weight_sum,
    }
end

local function identity_measure()
    return {
        weight = 0,
        count = 0,
        max_mean = -math.huge,
        mean_weight_sum = 0,
    }
end

local function compare_centroid(a, b)
    if a.mean < b.mean then return -1 end
    if a.mean > b.mean then return 1 end
    return 0
end

function TDigest.new(delta)
    delta = delta or DEFAULT_DELTA
    local self = setmetatable({}, TDigest)
    self.delta = delta + 0.0
    self.tree = Tree234.new({
        measure_fn = centroid_measure,
        combine_fn = combine_measure,
        identity_fn = identity_measure,
        compare_fn = compare_centroid,
    })
    self.buffer = {}
    self.total_weight = 0.0
    self.min_val = math.huge
    self.max_val = -math.huge
    self.buffer_cap = math.ceil(delta * BUFFER_FACTOR)
    return self
end

function TDigest:add(value, weight)
    value = value + 0.0
    weight = (weight or 1.0) + 0.0
    self.buffer[#self.buffer + 1] = {mean = value, weight = weight}
    self.total_weight = self.total_weight + weight
    if value < self.min_val then self.min_val = value end
    if value > self.max_val then self.max_val = value end
    if #self.buffer >= self.buffer_cap then
        self:compress()
    end
    return self
end

local function merge_into_last(centroids, c)
    local last = centroids[#centroids]
    local new_weight = last.weight + c.weight
    last.mean = (last.mean * last.weight + c.mean * c.weight) / new_weight
    last.weight = new_weight
end

function TDigest:_k(q)
    return (self.delta / (2.0 * math.pi)) * math.asin(2.0 * q - 1.0)
end

function TDigest:compress()
    if #self.buffer == 0 and self.tree:size() <= 1 then return end

    -- Collect all centroids from tree and buffer
    local all = self.tree:collect()
    for _, c in ipairs(self.buffer) do
        all[#all + 1] = {mean = c.mean, weight = c.weight}
    end
    self.buffer = {}

    table.sort(all, function(a, b) return a.mean < b.mean end)

    -- Merge centroids according to K1 scale function
    local merged = {{mean = all[1].mean, weight = all[1].weight}}
    local weight_so_far = 0.0
    local n = self.total_weight

    for i = 2, #all do
        local proposed = merged[#merged].weight + all[i].weight
        local q0 = weight_so_far / n
        local q1 = (weight_so_far + proposed) / n

        if proposed <= 1 and #all > 1 then
            merge_into_last(merged, all[i])
        elseif self:_k(q1) - self:_k(q0) <= 1.0 then
            merge_into_last(merged, all[i])
        else
            weight_so_far = weight_so_far + merged[#merged].weight
            merged[#merged + 1] = {mean = all[i].mean, weight = all[i].weight}
        end
    end

    -- Rebuild tree from sorted merged centroids
    self.tree:build_from_sorted(merged)
    return self
end

function TDigest:quantile(q)
    if #self.buffer > 0 then self:compress() end
    local centroids = self.tree:collect()
    if #centroids == 0 then return nil end
    if #centroids == 1 then return centroids[1].mean end

    if q < 0.0 then q = 0.0 end
    if q > 1.0 then q = 1.0 end

    local n = self.total_weight
    local target = q * n
    local cumulative = 0.0
    local count = #centroids

    for i = 1, count do
        local cmean = centroids[i].mean
        local cweight = centroids[i].weight
        local mid = cumulative + cweight / 2.0

        if i == 1 then
            if target < cweight / 2.0 then
                if cweight == 1 then return self.min_val end
                return self.min_val + (cmean - self.min_val) * (target / (cweight / 2.0))
            end
        end

        if i == count then
            if target > n - cweight / 2.0 then
                if cweight == 1 then return self.max_val end
                local remaining = n - cweight / 2.0
                return cmean + (self.max_val - cmean) * ((target - remaining) / (cweight / 2.0))
            end
            return cmean
        end

        local nmean = centroids[i + 1].mean
        local nweight = centroids[i + 1].weight
        local next_mid = cumulative + cweight + nweight / 2.0

        if target <= next_mid then
            local frac
            if next_mid == mid then
                frac = 0.5
            else
                frac = (target - mid) / (next_mid - mid)
            end
            return cmean + frac * (nmean - cmean)
        end

        cumulative = cumulative + cweight
    end

    return self.max_val
end

function TDigest:cdf(x)
    if #self.buffer > 0 then self:compress() end
    local centroids = self.tree:collect()
    if #centroids == 0 then return nil end
    if x <= self.min_val then return 0.0 end
    if x >= self.max_val then return 1.0 end

    local n = self.total_weight
    local cumulative = 0.0
    local count = #centroids

    for i = 1, count do
        local cmean = centroids[i].mean
        local cweight = centroids[i].weight

        if i == 1 then
            if x < cmean then
                local inner_w = cweight / 2.0
                local frac = (cmean == self.min_val) and 1.0 or (x - self.min_val) / (cmean - self.min_val)
                return (inner_w * frac) / n
            elseif x == cmean then
                return (cweight / 2.0) / n
            end
        end

        if i == count then
            if x > cmean then
                local inner_w = cweight / 2.0
                local right_w = n - cumulative - cweight / 2.0
                local frac = (self.max_val == cmean) and 0.0 or (x - cmean) / (self.max_val - cmean)
                return (cumulative + cweight / 2.0 + right_w * frac) / n
            else
                return (cumulative + cweight / 2.0) / n
            end
        end

        local mid = cumulative + cweight / 2.0
        local nmean = centroids[i + 1].mean
        local nweight = centroids[i + 1].weight
        local next_cumulative = cumulative + cweight
        local next_mid = next_cumulative + nweight / 2.0

        if x < nmean then
            if cmean == nmean then
                return (mid + (next_mid - mid) / 2.0) / n
            end
            local frac = (x - cmean) / (nmean - cmean)
            return (mid + frac * (next_mid - mid)) / n
        end

        cumulative = cumulative + cweight
    end

    return 1.0
end

function TDigest:merge(other)
    if #other.buffer > 0 then other:compress() end
    local other_centroids = other.tree:collect()
    for _, c in ipairs(other_centroids) do
        self:add(c.mean, c.weight)
    end
    return self
end

function TDigest:size()
    return self.tree:size() + #self.buffer
end

function TDigest:centroid_count()
    if #self.buffer > 0 then self:compress() end
    return self.tree:size()
end

return TDigest
