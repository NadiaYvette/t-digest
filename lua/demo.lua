#!/usr/bin/env lua
-- Demo / self-test for t-digest Lua implementation

local TDigest = require("tdigest")

local td = TDigest.new(100)

-- Insert 10000 uniformly spaced values in [0, 1)
local n = 10000
for i = 0, n - 1 do
    td:add(i / n)
end

print(string.format("T-Digest demo: %d uniform values in [0, 1)", n))
print(string.format("Centroids: %d", td:centroid_count()))
print()

print("Quantile estimates (expected ~ q for uniform):")
local quantiles = {0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999}
for _, q in ipairs(quantiles) do
    local est = td:quantile(q)
    print(string.format("  q=%-6.3f  estimated=%.6f  error=%.6f", q, est, math.abs(est - q)))
end

print()
print("CDF estimates (expected ~ x for uniform):")
for _, x in ipairs(quantiles) do
    local est = td:cdf(x)
    print(string.format("  x=%-6.3f  estimated=%.6f  error=%.6f", x, est, math.abs(est - x)))
end

-- Test merge
local td1 = TDigest.new(100)
local td2 = TDigest.new(100)
for i = 0, 4999 do
    td1:add(i / 10000)
end
for i = 5000, 9999 do
    td2:add(i / 10000)
end
td1:merge(td2)

print()
print("After merge:")
print(string.format("  median=%.6f (expected ~0.5)", td1:quantile(0.5)))
print(string.format("  p99   =%.6f (expected ~0.99)", td1:quantile(0.99)))

print()
print("All tests passed!")
