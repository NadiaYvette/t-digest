// Dunning t-digest for online quantile estimation.
// Merging digest variant with K_1 (arcsine) scale function.

const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;

pub const Centroid = struct {
    mean: f64,
    weight: f64,
};

pub const default_delta: f64 = 100.0;
const buffer_factor: usize = 5;

pub const TDigest = struct {
    delta: f64,
    centroids: std.ArrayListUnmanaged(Centroid),
    buf: std.ArrayListUnmanaged(Centroid),
    total_weight: f64,
    min_val: f64,
    max_val: f64,
    buffer_cap: usize,
    allocator: Allocator,

    pub fn init(allocator: Allocator, delta: f64) TDigest {
        const cap: usize = @intFromFloat(@ceil(delta * @as(f64, @floatFromInt(buffer_factor))));
        return TDigest{
            .delta = delta,
            .centroids = .empty,
            .buf = .empty,
            .total_weight = 0.0,
            .min_val = math.inf(f64),
            .max_val = -math.inf(f64),
            .buffer_cap = cap,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TDigest) void {
        self.centroids.deinit(self.allocator);
        self.buf.deinit(self.allocator);
    }

    fn k(self: *const TDigest, q: f64) f64 {
        return (self.delta / (2.0 * math.pi)) * math.asin(2.0 * q - 1.0);
    }

    pub fn compress(self: *TDigest) !void {
        if (self.buf.items.len == 0 and self.centroids.items.len <= 1) return;

        var all: std.ArrayListUnmanaged(Centroid) = .empty;
        defer all.deinit(self.allocator);
        try all.ensureTotalCapacity(self.allocator, self.centroids.items.len + self.buf.items.len);
        for (self.centroids.items) |c_item| {
            try all.append(self.allocator, c_item);
        }
        for (self.buf.items) |c_item| {
            try all.append(self.allocator, c_item);
        }
        self.buf.clearRetainingCapacity();

        std.mem.sort(Centroid, all.items, {}, struct {
            fn lessThan(_: void, a: Centroid, b: Centroid) bool {
                return a.mean < b.mean;
            }
        }.lessThan);

        self.centroids.clearRetainingCapacity();
        try self.centroids.append(self.allocator, Centroid{ .mean = all.items[0].mean, .weight = all.items[0].weight });
        var weight_so_far: f64 = 0.0;
        const n = self.total_weight;

        for (all.items[1..]) |item| {
            const last_idx = self.centroids.items.len - 1;
            const proposed = self.centroids.items[last_idx].weight + item.weight;
            const q0 = weight_so_far / n;
            const q1 = (weight_so_far + proposed) / n;

            if ((proposed <= 1.0 and all.items.len > 1) or (self.k(q1) - self.k(q0) <= 1.0)) {
                const last = &self.centroids.items[last_idx];
                const new_weight = last.weight + item.weight;
                last.mean = (last.mean * last.weight + item.mean * item.weight) / new_weight;
                last.weight = new_weight;
            } else {
                weight_so_far += self.centroids.items[last_idx].weight;
                try self.centroids.append(self.allocator, Centroid{ .mean = item.mean, .weight = item.weight });
            }
        }
    }

    pub fn add(self: *TDigest, value: f64, weight: f64) !void {
        try self.buf.append(self.allocator, Centroid{ .mean = value, .weight = weight });
        self.total_weight += weight;
        if (value < self.min_val) self.min_val = value;
        if (value > self.max_val) self.max_val = value;
        if (self.buf.items.len >= self.buffer_cap) {
            try self.compress();
        }
    }

    pub fn quantile(self: *TDigest, q_in: f64) !?f64 {
        if (self.buf.items.len > 0) try self.compress();
        if (self.centroids.items.len == 0) return null;
        if (self.centroids.items.len == 1) return self.centroids.items[0].mean;

        const q = @max(0.0, @min(1.0, q_in));
        const n = self.total_weight;
        const target = q * n;

        var cumulative: f64 = 0.0;
        for (self.centroids.items, 0..) |c, i| {
            const mid = cumulative + c.weight / 2.0;

            // Left boundary
            if (i == 0 and target < c.weight / 2.0) {
                if (c.weight == 1.0) return self.min_val;
                return self.min_val + (c.mean - self.min_val) * (target / (c.weight / 2.0));
            }

            // Right boundary
            if (i == self.centroids.items.len - 1) {
                if (target > n - c.weight / 2.0) {
                    if (c.weight == 1.0) return self.max_val;
                    const remaining = n - c.weight / 2.0;
                    return c.mean + (self.max_val - c.mean) * ((target - remaining) / (c.weight / 2.0));
                }
                return c.mean;
            }

            // Interpolation
            const next_c = self.centroids.items[i + 1];
            const next_mid = cumulative + c.weight + next_c.weight / 2.0;

            if (target <= next_mid) {
                const frac = if (next_mid == mid) 0.5 else (target - mid) / (next_mid - mid);
                return c.mean + frac * (next_c.mean - c.mean);
            }

            cumulative += c.weight;
        }

        return self.max_val;
    }

    pub fn cdf(self: *TDigest, x: f64) !?f64 {
        if (self.buf.items.len > 0) try self.compress();
        if (self.centroids.items.len == 0) return null;
        if (x <= self.min_val) return 0.0;
        if (x >= self.max_val) return 1.0;

        const n = self.total_weight;
        var cumulative: f64 = 0.0;

        for (self.centroids.items, 0..) |c, i| {
            if (i == 0) {
                if (x < c.mean) {
                    const inner_w = c.weight / 2.0;
                    const frac = if (c.mean == self.min_val) 1.0 else (x - self.min_val) / (c.mean - self.min_val);
                    return (inner_w * frac) / n;
                } else if (x == c.mean) {
                    return (c.weight / 2.0) / n;
                }
            }

            if (i == self.centroids.items.len - 1) {
                if (x > c.mean) {
                    const right_w = n - cumulative - c.weight / 2.0;
                    const frac = if (self.max_val == c.mean) 0.0 else (x - c.mean) / (self.max_val - c.mean);
                    return (cumulative + c.weight / 2.0 + right_w * frac) / n;
                } else {
                    return (cumulative + c.weight / 2.0) / n;
                }
            }

            const mid_val = cumulative + c.weight / 2.0;
            const next_c = self.centroids.items[i + 1];
            const next_cumulative = cumulative + c.weight;
            const next_mid = next_cumulative + next_c.weight / 2.0;

            if (x < next_c.mean) {
                if (c.mean == next_c.mean) {
                    return (mid_val + (next_mid - mid_val) / 2.0) / n;
                }
                const frac = (x - c.mean) / (next_c.mean - c.mean);
                return (mid_val + frac * (next_mid - mid_val)) / n;
            }

            cumulative += c.weight;
        }

        return 1.0;
    }

    pub fn mergeFrom(self: *TDigest, other: *TDigest) !void {
        if (other.buf.items.len > 0) try other.compress();
        for (other.centroids.items) |c| {
            try self.add(c.mean, c.weight);
        }
    }

    pub fn centroidCount(self: *TDigest) !usize {
        if (self.buf.items.len > 0) try self.compress();
        return self.centroids.items.len;
    }
};
